// Banc de `setUserBanned` (functions/bannissement.js).
//
//   cd functions && npm test
//
// Même principe que roles_admin.test.js : doublures qui enregistrent, pas de
// réseau. On vérifie qui peut bannir qui, ce qui est écrit dans Postgres
// (sentinelle comprise), que Firebase Auth est désactivé ET les jetons
// révoqués, et ce qui reste quand une étape échoue.

"use strict";

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  PREFIXE_SESSION_BANNIE,
  executerSetUserBanned,
  creerCallableSetUserBanned,
} = require("../bannissement");

class HttpsErreur extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const SUPER = "super_A";
const MOD = "mod_C";
const CIBLE = "cible_B";
const T0 = 1_760_400_000_000;

const compte = (id, role, extra = {}) => ({
  id,
  email: `${id}@exemple.invalid`,
  displayName: `Nom ${id}`,
  isAdmin: role !== null,
  adminRole: role,
  isBanned: false,
  ...extra,
});

function doublures({ comptes, echoue = {} }) {
  const trace = [];
  return {
    trace,
    deps: {
      HttpsError: HttpsErreur,
      maintenant: () => T0,
      lireCompte: async (uid) => {
        if (echoue.lecture) throw new Error("ECONNRESET");
        return Object.prototype.hasOwnProperty.call(comptes, uid) ? comptes[uid] : null;
      },
      ecrireBan: async (uid, etat) => {
        trace.push(["postgres", uid, etat]);
        if (echoue.postgres) throw new Error("42501");
        return Object.prototype.hasOwnProperty.call(comptes, uid) && comptes[uid] !== null;
      },
      desactiverCompte: async (uid, disabled) => {
        trace.push(["auth.disabled", uid, disabled]);
        if (echoue.auth) throw new Error("auth/user-not-found");
      },
      revoquerJetons: async (uid) => {
        trace.push(["auth.revoke", uid]);
      },
      journaliser: async (entree) => {
        trace.push(["journal", entree]);
        return !echoue.journal;
      },
    },
  };
}

const ctx = (uid) => ({ auth: { uid, token: {} } });

async function attendreRefus(promesse, code) {
  let erreur = null;
  try {
    await promesse;
  } catch (e) {
    erreur = e;
  }
  assert.ok(erreur, `attendu un refus ${code}, obtenu un succès`);
  assert.equal(erreur.code, code, `attendu ${code}, obtenu ${erreur.code} (${erreur.message})`);
  return erreur;
}

const base = () =>
  doublures({
    comptes: {
      [SUPER]: compte(SUPER, "superAdmin"),
      [MOD]: compte(MOD, "contentMod"),
      [CIBLE]: compte(CIBLE, null),
    },
  });

describe("refus — rien n'est écrit", () => {
  test("sans authentification", async () => {
    const { trace, deps } = base();
    await attendreRefus(
      executerSetUserBanned({ uid: CIBLE, banned: true, reason: "spam" }, {}, deps),
      "unauthenticated",
    );
    assert.deepEqual(trace, []);
  });

  test("arguments : uid malformé, banned non booléen, motif absent ou trop long", async () => {
    const { trace, deps } = base();
    const cas = [
      { uid: 'x")&("', banned: true, reason: "spam" },
      { uid: CIBLE, banned: "true", reason: "spam" },
      { uid: CIBLE, banned: true },
      { uid: CIBLE, banned: true, reason: "   " },
      { uid: CIBLE, banned: true, reason: "x".repeat(501) },
    ];
    for (const data of cas) {
      await attendreRefus(executerSetUserBanned(data, ctx(SUPER), deps), "invalid-argument");
    }
    assert.deepEqual(trace, []);
  });

  test("débannir n'exige pas de motif", async () => {
    const { deps } = base();
    const r = await executerSetUserBanned({ uid: CIBLE, banned: false }, ctx(SUPER), deps);
    assert.equal(r.action, "unban_user");
  });

  test("soi-même, avant toute lecture", async () => {
    const { trace, deps } = base();
    let lectures = 0;
    deps.lireCompte = async () => {
      lectures++;
      return compte(SUPER, "superAdmin");
    };
    await attendreRefus(
      executerSetUserBanned({ uid: SUPER, banned: true, reason: "x" }, ctx(SUPER), deps),
      "permission-denied",
    );
    assert.equal(lectures, 0);
    assert.deepEqual(trace, []);
  });

  test("appelant sans rôle, businessMod, financeMod, ou absent de Postgres", async () => {
    for (const appelant of [compte("a", null), compte("a", "businessMod"), compte("a", "financeMod"), null]) {
      const { trace, deps } = doublures({ comptes: { a: appelant, [CIBLE]: compte(CIBLE, null) } });
      await attendreRefus(
        executerSetUserBanned({ uid: CIBLE, banned: true, reason: "x" }, ctx("a"), deps),
        "permission-denied",
      );
      assert.deepEqual(trace, [], `écriture malgré le refus pour ${JSON.stringify(appelant)}`);
    }
  });

  test("appelant contentMod dont is_admin est faux : refusé", async () => {
    const { trace, deps } = doublures({
      comptes: { a: compte("a", "contentMod", { isAdmin: false }), [CIBLE]: compte(CIBLE, null) },
    });
    await attendreRefus(
      executerSetUserBanned({ uid: CIBLE, banned: true, reason: "x" }, ctx("a"), deps),
      "permission-denied",
    );
    assert.deepEqual(trace, []);
  });

  test("cible absente", async () => {
    const { trace, deps } = base();
    await attendreRefus(
      executerSetUserBanned({ uid: "inconnu", banned: true, reason: "x" }, ctx(SUPER), deps),
      "not-found",
    );
    assert.deepEqual(trace, []);
  });

  test("un superAdmin ne se bannit pas, même par un superAdmin", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), autre: compte("autre", "superAdmin") },
    });
    await attendreRefus(
      executerSetUserBanned({ uid: "autre", banned: true, reason: "x" }, ctx(SUPER), deps),
      "permission-denied",
    );
    assert.deepEqual(trace, []);
  });

  test("un contentMod ne bannit pas un autre admin ; un superAdmin, si", async () => {
    const comptes = () => ({
      [SUPER]: compte(SUPER, "superAdmin"),
      [MOD]: compte(MOD, "contentMod"),
      fin: compte("fin", "financeMod"),
    });
    const a = doublures({ comptes: comptes() });
    await attendreRefus(
      executerSetUserBanned({ uid: "fin", banned: true, reason: "x" }, ctx(MOD), a.deps),
      "permission-denied",
    );
    assert.deepEqual(a.trace, []);

    const b = doublures({ comptes: comptes() });
    const r = await executerSetUserBanned({ uid: "fin", banned: true, reason: "x" }, ctx(SUPER), b.deps);
    assert.equal(r.banned, true);
  });

  test("base injoignable : unavailable", async () => {
    const { trace, deps } = doublures({ comptes: {}, echoue: { lecture: true } });
    await attendreRefus(
      executerSetUserBanned({ uid: CIBLE, banned: true, reason: "x" }, ctx(SUPER), deps),
      "unavailable",
    );
    assert.deepEqual(trace, []);
  });
});

describe("parcours nominal", () => {
  test("bannir : Postgres (drapeaux, motif, banned_by, sentinelle), désactivation, révocation, journal", async () => {
    const { trace, deps } = base();
    const r = await executerSetUserBanned(
      { uid: CIBLE, banned: true, reason: "  spam répété  " },
      ctx(MOD),
      deps,
    );
    assert.deepEqual(trace.slice(0, 3), [
      [
        "postgres",
        CIBLE,
        { banned: true, reason: "spam répété", by: MOD, sessionId: `${PREFIXE_SESSION_BANNIE}${T0}` },
      ],
      ["auth.disabled", CIBLE, true],
      ["auth.revoke", CIBLE],
    ]);
    const [, journal] = trace[3];
    assert.equal(journal.action, "ban_user");
    assert.equal(journal.adminId, MOD);
    assert.equal(journal.targetId, CIBLE);
    assert.deepEqual(journal.details, {
      reason: "spam répété",
      targetEmail: `${CIBLE}@exemple.invalid`,
      targetName: `Nom ${CIBLE}`,
      wasBanned: false,
    });
    assert.deepEqual(r, { uid: CIBLE, banned: true, action: "ban_user", journalise: true });
  });

  test("la sentinelle porte le préfixe que SessionService lit", () => {
    assert.equal(PREFIXE_SESSION_BANNIE, "banned_");
  });

  test("débannir : drapeaux remis à zéro, compte réactivé, PAS de révocation, journal unban_user", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null, { isBanned: true }) },
    });
    const r = await executerSetUserBanned({ uid: CIBLE, banned: false }, ctx(SUPER), deps);
    assert.deepEqual(trace.slice(0, 2), [
      ["postgres", CIBLE, { banned: false, reason: null, by: null, sessionId: null }],
      ["auth.disabled", CIBLE, false],
    ]);
    assert.equal(trace.filter((t) => t[0] === "auth.revoke").length, 0);
    assert.equal(trace[2][1].action, "unban_user");
    assert.equal(trace[2][1].details.wasBanned, true);
    assert.equal(r.banned, false);
  });

  test("journal refusé : l'action tient, le résultat le dit", async () => {
    const { deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      echoue: { journal: true },
    });
    const r = await executerSetUserBanned({ uid: CIBLE, banned: true, reason: "x" }, ctx(SUPER), deps);
    assert.equal(r.journalise, false);
    assert.equal(r.banned, true);
  });
});

describe("échec d'une étape", () => {
  test("Postgres refuse : Firebase Auth n'est pas touché", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      echoue: { postgres: true },
    });
    await attendreRefus(
      executerSetUserBanned({ uid: CIBLE, banned: true, reason: "x" }, ctx(SUPER), deps),
      "internal",
    );
    assert.equal(trace.length, 1);
    assert.equal(trace[0][0], "postgres");
  });

  test("Firebase Auth échoue au bannissement : Postgres reste banni (éjecté), internal qui dit de relancer", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      echoue: { auth: true },
    });
    const e = await attendreRefus(
      executerSetUserBanned({ uid: CIBLE, banned: true, reason: "x" }, ctx(SUPER), deps),
      "internal",
    );
    assert.match(e.message, /relancer/);
    assert.equal(trace.filter((t) => t[0] === "journal").length, 0);
    assert.equal(trace[0][2].banned, true);
  });

  test("Firebase Auth échoue au débannissement : le message dit que le compte reste désactivé", async () => {
    const { deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null, { isBanned: true }) },
      echoue: { auth: true },
    });
    const e = await attendreRefus(
      executerSetUserBanned({ uid: CIBLE, banned: false }, ctx(SUPER), deps),
      "internal",
    );
    assert.match(e.message, /toujours désactivé/);
  });
});

describe("câblage firebase-functions (v1)", () => {
  test("context.auth traverse onCall", async () => {
    const fft = require("firebase-functions-test")();
    const functions = require("firebase-functions");
    try {
      const { trace, deps } = base();
      delete deps.HttpsError;
      const wrapped = fft.wrap(creerCallableSetUserBanned(functions, deps));
      const r = await wrapped({ uid: CIBLE, banned: true, reason: "x" }, ctx(SUPER));
      assert.equal(r.action, "ban_user");
      assert.deepEqual(trace[1], ["auth.disabled", CIBLE, true]);

      let erreur = null;
      try {
        await wrapped({ uid: CIBLE, banned: true, reason: "x" }, {});
      } catch (e) {
        erreur = e;
      }
      assert.ok(erreur instanceof functions.https.HttpsError);
      assert.equal(erreur.code, "unauthenticated");
    } finally {
      fft.cleanup();
    }
  });
});
