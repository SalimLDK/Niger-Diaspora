// Banc de `setAdminRole` (functions/roles_admin.js).
//
//   cd functions && npm test          # node --test test/
//
// Ni réseau, ni émulateur, ni identifiants : les accès (Postgres, Auth, RTDB,
// journal) sont des doublures qui ENREGISTRENT ce que la fonction leur
// demande. On vérifie les refus, l'ordre des écritures, et ce qui reste
// écrit quand une étape échoue — c'est là que vivait l'admin fantôme.
//
// Le dernier cas passe par `firebase-functions-test` pour prouver que le
// câblage `functions.https.onCall` transmet bien `context.auth` au module :
// tout le reste teste le module directement.

"use strict";

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  ROLES_ADMIN,
  ROLES_LIMITES,
  ROLES_ATTRIBUABLES,
  claimsPour,
  estRoleHistorique,
  normaliserRole,
  actionJournal,
  executerSetAdminRole,
  creerCallableSetAdminRole,
} = require("../roles_admin");

/** Doublure de `functions.https.HttpsError`, sans charger firebase-functions. */
class HttpsErreur extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const SUPER = "super_A";
const CIBLE = "cible_B";

const compte = (id, role, extra = {}) => ({
  id,
  email: `${id}@exemple.invalid`,
  displayName: `Nom ${id}`,
  isAdmin: role !== null,
  adminRole: role,
  ...extra,
});

/**
 * Fabrique des dépendances qui journalisent chaque appel dans `trace`.
 *
 * @param {object} options
 * @param {Record<string, object|null>} options.comptes uid → ligne Postgres
 * @param {number} [options.superAdmins]
 * @param {Partial<Record<"claim"|"rtdb"|"postgres"|"journal", boolean>>} [options.echoue]
 */
function doublures({ comptes, superAdmins = 2, echoue = {} }) {
  const trace = [];
  return {
    trace,
    deps: {
      HttpsError: HttpsErreur,
      lireCompte: async (uid) => {
        if (echoue.lecture) throw new Error("ECONNRESET");
        return Object.prototype.hasOwnProperty.call(comptes, uid) ? comptes[uid] : null;
      },
      compterSuperAdmins: async () => superAdmins,
      ecrireRoleAdmin: async (uid, role) => {
        trace.push(["postgres", uid, role]);
        if (echoue.postgres) throw new Error("42501");
        return Object.prototype.hasOwnProperty.call(comptes, uid) && comptes[uid] !== null;
      },
      poserClaim: async (uid, role) => {
        trace.push(["claim", uid, role]);
        if (echoue.claim) throw new Error("auth/internal-error");
      },
      ecrireAdminsRtdb: async (uid, present) => {
        trace.push(["rtdb", uid, present]);
        if (echoue.rtdb) throw new Error("PERMISSION_DENIED");
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

describe("normaliserRole", () => {
  test("révocation : null, vide, undefined, none", () => {
    for (const v of [null, "", undefined, "none"]) {
      assert.deepEqual(normaliserRole(v), { ok: true, role: null });
    }
  });
  test("les quatre rôles, tels quels", () => {
    for (const r of ROLES_ADMIN) {
      assert.deepEqual(normaliserRole(r), { ok: true, role: r });
    }
  });
  test("tout le reste est refusé (casse, alias, objets)", () => {
    for (const v of ["SuperAdmin", "admin", "superadmin ", 1, {}, ["superAdmin"], true]) {
      assert.equal(normaliserRole(v).ok, false, `accepté à tort : ${JSON.stringify(v)}`);
    }
  });
});

describe("actionJournal", () => {
  test("nomme l'action comme le panneau le faisait", () => {
    assert.equal(actionJournal(null, "contentMod"), "assign_role");
    assert.equal(actionJournal("contentMod", "businessMod"), "change_role");
    assert.equal(actionJournal("contentMod", null), "revoke_role");
    assert.equal(actionJournal("contentMod", "contentMod"), "sync_role");
    assert.equal(actionJournal(null, null), "sync_role");
  });
});

describe("refus — rien n'est écrit", () => {
  const base = () =>
    doublures({ comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) } });

  test("sans authentification", async () => {
    const { trace, deps } = base();
    await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, {}, deps),
      "unauthenticated",
    );
    await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, { auth: null }, deps),
      "unauthenticated",
    );
    assert.deepEqual(trace, []);
  });

  test("uid absent ou malformé", async () => {
    const { trace, deps } = base();
    for (const uid of [undefined, null, "", 42, 'x")&id=not.is.null&("', "a".repeat(129)]) {
      await attendreRefus(
        executerSetAdminRole({ uid, adminRole: "contentMod" }, ctx(SUPER), deps),
        "invalid-argument",
      );
    }
    assert.deepEqual(trace, []);
  });

  test("rôle inconnu", async () => {
    const { trace, deps } = base();
    await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "god" }, ctx(SUPER), deps),
      "invalid-argument",
    );
    assert.deepEqual(trace, []);
  });

  test("sa propre ligne, même superAdmin — avant toute lecture", async () => {
    const { trace, deps } = base();
    let lectures = 0;
    deps.lireCompte = async () => {
      lectures++;
      return compte(SUPER, "superAdmin");
    };
    await attendreRefus(
      executerSetAdminRole({ uid: SUPER, adminRole: "none" }, ctx(SUPER), deps),
      "permission-denied",
    );
    assert.equal(lectures, 0, "la base ne doit pas être lue pour refuser sa propre ligne");
    assert.deepEqual(trace, []);
  });

  test("appelant contentMod, ou sans ligne Postgres, ou avec un seul des deux drapeaux", async () => {
    const cas = [
      compte("mod", "contentMod"),
      null,
      compte("moitie", "superAdmin", { isAdmin: false }),
      compte("moitie2", null, { isAdmin: true }),
    ];
    for (const appelant of cas) {
      const { trace, deps } = doublures({
        comptes: { appelant, [CIBLE]: compte(CIBLE, null) },
      });
      await attendreRefus(
        executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx("appelant"), deps),
        "permission-denied",
      );
      assert.deepEqual(trace, [], `écriture malgré le refus pour ${JSON.stringify(appelant)}`);
    }
  });

  test("appelant qui n'a QUE le claim superAdmin : refusé, Postgres fait foi", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, null), [CIBLE]: compte(CIBLE, null) },
    });
    await attendreRefus(
      executerSetAdminRole(
        { uid: CIBLE, adminRole: "contentMod" },
        { auth: { uid: SUPER, token: { adminRole: "superAdmin" } } },
        deps,
      ),
      "permission-denied",
    );
    assert.deepEqual(trace, []);
  });

  test("cible sans ligne Postgres", async () => {
    const { trace, deps } = doublures({ comptes: { [SUPER]: compte(SUPER, "superAdmin") } });
    await attendreRefus(
      executerSetAdminRole({ uid: "inconnu", adminRole: "contentMod" }, ctx(SUPER), deps),
      "not-found",
    );
    assert.deepEqual(trace, []);
  });

  test("base injoignable : unavailable, pas permission-denied", async () => {
    const { trace, deps } = doublures({ comptes: {}, echoue: { lecture: true } });
    await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps),
      "unavailable",
    );
    assert.deepEqual(trace, []);
  });

  test("dernier superAdmin : refusé si le compte rendrait zéro", async () => {
    // Un seul superAdmin compté alors que l'appelant en est un et vise un
    // autre : état incohérent ou course. La garde refuse quand même.
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, "superAdmin") },
      superAdmins: 1,
    });
    await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps),
      "failed-precondition",
    );
    assert.deepEqual(trace, []);
  });

  test("dernier superAdmin : la garde ne s'applique qu'à une rétrogradation de superAdmin", async () => {
    let compte_ = 0;
    const { deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, "contentMod") },
      superAdmins: 1,
    });
    deps.compterSuperAdmins = async () => {
      compte_++;
      return 1;
    };
    await executerSetAdminRole({ uid: CIBLE, adminRole: "none" }, ctx(SUPER), deps);
    assert.equal(compte_, 0, "pas de comptage quand la cible n'est pas superAdmin");
  });
});

describe("parcours nominal — les trois dérivés, dans l'ordre, puis le journal", () => {
  test("assignation : Postgres (les deux colonnes), claim, RTDB, journal assign_role", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
    });
    const r = await executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps);

    assert.deepEqual(trace.slice(0, 3), [
      ["postgres", CIBLE, "contentMod"],
      ["claim", CIBLE, "contentMod"],
      ["rtdb", CIBLE, true],
    ]);
    const [, journal] = trace[3];
    assert.equal(journal.action, "assign_role");
    assert.equal(journal.adminId, SUPER);
    assert.equal(journal.targetId, CIBLE);
    assert.equal(journal.targetType, "user");
    assert.deepEqual(journal.details, {
      previousRole: "none",
      newRole: "contentMod",
      targetEmail: `${CIBLE}@exemple.invalid`,
      targetName: `Nom ${CIBLE}`,
    });
    assert.deepEqual(r, {
      uid: CIBLE,
      previousRole: "none",
      adminRole: "contentMod",
      action: "assign_role",
      journalise: true,
    });
  });

  test("révocation : is_admin ET admin_role tombent, claim retiré, nœud RTDB retiré", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, "businessMod") },
    });
    const r = await executerSetAdminRole({ uid: CIBLE, adminRole: "none" }, ctx(SUPER), deps);
    assert.deepEqual(trace.slice(0, 3), [
      ["postgres", CIBLE, null],
      ["claim", CIBLE, null],
      ["rtdb", CIBLE, false],
    ]);
    assert.equal(trace[3][1].action, "revoke_role");
    assert.equal(r.previousRole, "businessMod");
    assert.equal(r.adminRole, "none");
  });

  test("changement de rôle : change_role ; un autre superAdmin peut être rétrogradé s'il en reste", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, "superAdmin") },
      superAdmins: 2,
    });
    const r = await executerSetAdminRole({ uid: CIBLE, adminRole: "financeMod" }, ctx(SUPER), deps);
    assert.equal(trace[3][1].action, "change_role");
    assert.equal(r.action, "change_role");
  });

  test("rôle inchangé : les dérivés sont reposés quand même (réconciliation), action sync_role", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, "contentMod") },
    });
    const r = await executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps);
    assert.equal(trace.filter((t) => t[0] !== "journal").length, 3);
    assert.equal(r.action, "sync_role");
  });

  test("journal refusé : l'action tient, le résultat le dit", async () => {
    const { deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      echoue: { journal: true },
    });
    const r = await executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps);
    assert.equal(r.journalise, false);
    assert.equal(r.adminRole, "contentMod");
  });
});

describe("échec d'une étape — ce qui reste écrit", () => {
  test("Postgres refuse : rien d'autre n'est touché", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      echoue: { postgres: true },
    });
    await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps),
      "internal",
    );
    assert.deepEqual(trace, [["postgres", CIBLE, "contentMod"]]);
  });

  test("claim refusé : Postgres est REMIS à sa valeur d'avant, pas de RTDB, pas de journal", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, "contentMod") },
      echoue: { claim: true },
    });
    const e = await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "superAdmin" }, ctx(SUPER), deps),
      "internal",
    );
    assert.deepEqual(trace, [
      ["postgres", CIBLE, "superAdmin"],
      ["claim", CIBLE, "superAdmin"],
      ["postgres", CIBLE, "contentMod"], // remise
    ]);
    assert.match(e.message, /n'a pas été modifié/);
  });

  test("claim refusé ET remise impossible : le message le dit", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      echoue: { claim: true },
    });
    let appels = 0;
    const ecrire = deps.ecrireRoleAdmin;
    deps.ecrireRoleAdmin = async (uid, role) => {
      appels++;
      if (appels === 2) throw new Error("ECONNRESET");
      return ecrire(uid, role);
    };
    const e = await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps),
      "internal",
    );
    assert.match(e.message, /base laissée modifiée/);
    assert.equal(trace.filter((t) => t[0] === "rtdb").length, 0);
  });

  test("RTDB refuse : Postgres et claim restent posés (cohérents), internal qui dit de relancer", async () => {
    const { trace, deps } = doublures({
      comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      echoue: { rtdb: true },
    });
    const e = await attendreRefus(
      executerSetAdminRole({ uid: CIBLE, adminRole: "contentMod" }, ctx(SUPER), deps),
      "internal",
    );
    assert.deepEqual(trace, [
      ["postgres", CIBLE, "contentMod"],
      ["claim", CIBLE, "contentMod"],
      ["rtdb", CIBLE, true],
    ]);
    assert.match(e.message, /relancer/);
  });
});

describe("câblage firebase-functions (v1) — via firebase-functions-test", () => {
  test("context.auth traverse onCall ; sans auth, HttpsError unauthenticated", async () => {
    const fft = require("firebase-functions-test")();
    const functions = require("firebase-functions");
    try {
      const { trace, deps } = doublures({
        comptes: { [SUPER]: compte(SUPER, "superAdmin"), [CIBLE]: compte(CIBLE, null) },
      });
      delete deps.HttpsError; // la fabrique fournit le vrai
      const callable = creerCallableSetAdminRole(functions, deps);
      const wrapped = fft.wrap(callable);

      const r = await wrapped({ uid: CIBLE, adminRole: "financeMod" }, ctx(SUPER));
      assert.equal(r.adminRole, "financeMod");
      assert.deepEqual(trace[1], ["claim", CIBLE, "financeMod"]);

      let erreur = null;
      try {
        await wrapped({ uid: CIBLE, adminRole: "financeMod" }, {});
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


describe("rôles à périmètre limité", () => {
  test("ne figurent pas dans ROLES_ADMIN (porte d'autorisation d'index.js)", () => {
    for (const r of ROLES_LIMITES) {
      assert.equal(ROLES_ADMIN.includes(r), false, `${r} ne doit pas ouvrir les portes admin`);
    }
  });
  test("sont attribuables, comme les quatre historiques", () => {
    for (const r of ROLES_ATTRIBUABLES) {
      assert.deepEqual(normaliserRole(r), { ok: true, role: r });
    }
    assert.equal(ROLES_ATTRIBUABLES.length, 8);
  });
  test("le claim d'un rôle limité n'est JAMAIS adminRole", () => {
    for (const r of ROLES_LIMITES) {
      assert.deepEqual(claimsPour(r), { adminRoleLimite: r });
    }
    for (const r of ROLES_ADMIN) {
      assert.deepEqual(claimsPour(r), { adminRole: r });
    }
    assert.equal(claimsPour(null), null);
  });
  test("seuls les rôles historiques entrent dans RTDB /admins", () => {
    assert.equal(estRoleHistorique("contentMod"), true);
    assert.equal(estRoleHistorique("auditor"), false);
    assert.equal(estRoleHistorique(null), false);
  });
});
