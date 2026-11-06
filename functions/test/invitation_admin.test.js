// Banc de `accepterInvitationAdmin` (functions/roles_admin.js).
//
//   cd functions && npm test
//
// Les accès (Postgres, Auth, RTDB, journal) sont des doublures qui enregistrent ce qu'on leur demande. On vérifie
// les refus (second facteur, connexion récente, invitation d'une autre personne), l'ordre des écritures, et ce qui
// reste en place quand une étape échoue : une invitation qui a échoué doit pouvoir être rejouée.

"use strict";

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  ROLES_LIMITES,
  executerAccepterInvitation,
  AUTHENTIFICATION_RECENTE_SECONDES,
} = require("../roles_admin");

class HttpsErreur extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const INVITE = "invite_C";
const ID = "123e4567-e89b-12d3-a456-426614174000";
const T0 = 1_800_000_000;

const compte = (extra = {}) => ({
  id: INVITE, email: "c@exemple.invalid", displayName: "Nom C", isAdmin: false, adminRole: null, isBanned: false, ...extra,
});

const contexte = (extra = {}) => ({
  auth: {
    uid: INVITE,
    token: { auth_time: T0 - 30, firebase: { sign_in_second_factor: "totp" }, ...extra },
  },
});

function doublures({ role = "auditor", echoue = {}, cible = compte() } = {}) {
  const trace = [];
  return {
    trace,
    deps: {
      HttpsError: HttpsErreur,
      maintenant: () => T0,
      lireCompte: async () => {
        trace.push(["lire"]);
        if (echoue.lecture) throw new Error("ECONNRESET");
        return cible;
      },
      reclamerInvitation: async (id, uid) => {
        trace.push(["reclamer", id, uid]);
        if (echoue.reclamation) throw new Error("P0002");
        return role;
      },
      rouvrirInvitation: async (id) => {
        trace.push(["rouvrir", id]);
        if (echoue.reouverture) throw new Error("reseau");
      },
      ecrireRoleAdmin: async (uid, r) => {
        trace.push(["postgres", uid, r]);
        if (echoue.postgres && r === role) throw new Error("42501");
        return !echoue.absent;
      },
      poserClaim: async (uid, r) => {
        trace.push(["claim", uid, r]);
        if (echoue.claim) throw new Error("auth");
      },
      ecrireAdminsRtdb: async (uid, present) => {
        trace.push(["rtdb", uid, present]);
        if (echoue.rtdb) throw new Error("rtdb");
      },
      journaliser: async (entree) => {
        trace.push(["journal", entree.action]);
        return !echoue.journal;
      },
    },
  };
}

const etapes = (trace) => trace.map((t) => t[0]);

async function refuse(promesse, code) {
  await assert.rejects(promesse, (e) => {
    assert.equal(e.code, code, `code attendu ${code}, reçu ${e.code} (${e.message})`);
    return true;
  });
}

describe("accepterInvitationAdmin : refus", () => {
  test("sans authentification", async () => {
    const { deps, trace } = doublures();
    await refuse(executerAccepterInvitation({ invitationId: ID }, {}, deps), "unauthenticated");
    assert.deepEqual(trace, []);
  });

  test("identifiant d'invitation absent ou mal formé", async () => {
    for (const v of [undefined, null, "", 3, "pas-un-uuid", "123e4567-e89b-12d3-a456-42661417400"]) {
      const { deps, trace } = doublures();
      await refuse(executerAccepterInvitation({ invitationId: v }, contexte(), deps), "invalid-argument");
      assert.deepEqual(trace, [], `rien ne doit être lu pour ${JSON.stringify(v)}`);
    }
  });

  test("sans second facteur dans le jeton", async () => {
    const { deps, trace } = doublures();
    await refuse(
      executerAccepterInvitation({ invitationId: ID }, { auth: { uid: INVITE, token: { auth_time: T0 - 5, firebase: {} } } }, deps),
      "permission-denied",
    );
    assert.deepEqual(trace, []);
  });

  test("connexion trop ancienne", async () => {
    const { deps, trace } = doublures();
    const ctx = contexte({ auth_time: T0 - AUTHENTIFICATION_RECENTE_SECONDES - 1 });
    await refuse(executerAccepterInvitation({ invitationId: ID }, ctx, deps), "failed-precondition");
    assert.deepEqual(trace, []);
  });

  test("auth_time absent : refusé (le doute n'ouvre rien)", async () => {
    const { deps } = doublures();
    const ctx = { auth: { uid: INVITE, token: { firebase: { sign_in_second_factor: "totp" } } } };
    await refuse(executerAccepterInvitation({ invitationId: ID }, ctx, deps), "failed-precondition");
  });

  test("compte suspendu", async () => {
    const { deps, trace } = doublures({ cible: compte({ isBanned: true }) });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "permission-denied");
    assert.equal(etapes(trace).includes("reclamer"), false);
  });

  test("invitation introuvable, expirée, déjà traitée ou d'une autre personne : la base refuse", async () => {
    const { deps, trace } = doublures({ echoue: { reclamation: true } });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "failed-precondition");
    assert.deepEqual(etapes(trace), ["lire", "reclamer"], "aucun rôle n'est écrit");
  });

  test("le rôle vient de l'invitation, jamais du client", async () => {
    const { deps, trace } = doublures({ role: "contentMod" });
    // Le client essaie de forcer superAdmin : ignoré.
    const r = await executerAccepterInvitation({ invitationId: ID, adminRole: "superAdmin", role: "superAdmin" }, contexte(), deps);
    assert.equal(r.role, "contentMod");
    assert.deepEqual(trace.find((t) => t[0] === "postgres"), ["postgres", INVITE, "contentMod"]);
  });

  test("un rôle inconnu du code déployé : rien d'écrit, invitation rouverte", async () => {
    const { deps, trace } = doublures({ role: "roleDuFutur" });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "internal");
    assert.deepEqual(etapes(trace), ["lire", "reclamer", "rouvrir"]);
  });
});

describe("accepterInvitationAdmin : parcours nominal", () => {
  test("écrit Postgres, puis le claim, puis RTDB, puis journalise", async () => {
    const { deps, trace } = doublures({ role: "contentMod" });
    const r = await executerAccepterInvitation({ invitationId: ID }, contexte(), deps);
    assert.deepEqual(r, { role: "contentMod", invitationId: ID });
    assert.deepEqual(etapes(trace), ["lire", "reclamer", "postgres", "claim", "rtdb", "journal"]);
    assert.deepEqual(trace.find((t) => t[0] === "rtdb"), ["rtdb", INVITE, true], "un rôle historique entre dans RTDB /admins");
    assert.deepEqual(trace.find((t) => t[0] === "journal"), ["journal", "ADMIN_ROLE_ACTIVATED"]);
  });

  test("un rôle limité n'entre pas dans RTDB /admins", async () => {
    for (const role of ROLES_LIMITES) {
      const { deps, trace } = doublures({ role });
      await executerAccepterInvitation({ invitationId: ID }, contexte(), deps);
      assert.deepEqual(trace.find((t) => t[0] === "rtdb"), ["rtdb", INVITE, false], `${role}`);
    }
  });
});

describe("accepterInvitationAdmin : échecs en cours de route", () => {
  test("Postgres refuse : invitation rouverte, ni claim ni RTDB", async () => {
    const { deps, trace } = doublures({ role: "auditor", echoue: { postgres: true } });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "internal");
    assert.deepEqual(etapes(trace), ["lire", "reclamer", "postgres", "rouvrir"]);
  });

  test("compte absent : invitation rouverte", async () => {
    const { deps, trace } = doublures({ echoue: { absent: true } });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "not-found");
    assert.equal(etapes(trace).at(-1), "rouvrir");
  });

  test("le claim échoue : Postgres est remis à sa valeur d'avant, l'invitation est rouverte", async () => {
    const { deps, trace } = doublures({ role: "auditor", echoue: { claim: true } });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "internal");
    assert.deepEqual(etapes(trace), ["lire", "reclamer", "postgres", "claim", "postgres", "rouvrir"]);
    assert.deepEqual(trace.filter((t) => t[0] === "postgres").at(-1), ["postgres", INVITE, null], "retour à « aucun rôle »");
  });

  test("RTDB échoue : l'erreur le dit, l'invitation reste acceptée (rejouer écrira les trois registres)", async () => {
    const { deps, trace } = doublures({ role: "contentMod", echoue: { rtdb: true } });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "internal");
    assert.equal(etapes(trace).includes("rouvrir"), false);
    assert.equal(etapes(trace).includes("journal"), false);
  });

  test("le journal échoue : l'activation réussit quand même", async () => {
    const { deps } = doublures({ role: "auditor", echoue: { journal: true } });
    const r = await executerAccepterInvitation({ invitationId: ID }, contexte(), deps);
    assert.equal(r.role, "auditor");
  });

  test("une réouverture impossible ne masque pas l'erreur d'origine", async () => {
    const { deps } = doublures({ role: "auditor", echoue: { postgres: true, reouverture: true } });
    await refuse(executerAccepterInvitation({ invitationId: ID }, contexte(), deps), "internal");
  });
});
