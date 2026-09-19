// Banc de la page de suppression de compte (public/delete-account*.html et
// public/assets/delete-account.js).
//
//   node --test tools/site_tests/suppression_compte_page.test.mjs
//
// Node >= 22.7 : le module du site est un module ES sans package.json, la
// détection de syntaxe le charge tel quel. (`--test` veut le fichier : sous
// Node 22 il ne développe pas un dossier.)
//
// Deux familles de garde-fous :
//   · le contrat HTTP (`requestDeletion`) rejoué avec un `fetch` factice — les
//     refus de la base, les pannes, et surtout ce qui ne doit JAMAIS passer pour
//     un succès ;
//   · la structure des deux pages : mêmes clés en FR et en EN, ce dont `mount`
//     a besoin dans le DOM, et l'absence de tout code qui supprimerait quelque
//     chose depuis la page (Firestore, deleteUser).
//
// Ce banc ne voit ni le rendu ni le navigateur : le câblage DOM se vérifie à la
// main (voir « Page de suppression de compte » dans TESTS_APPAREIL_A_FAIRE.md).

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import {
  formatDeadline,
  MOTIFS_DE_REFUS,
  parseDeadline,
  requestDeletion,
  SUPABASE_PUBLISHABLE_KEY,
  SUPABASE_URL,
} from '../../public/assets/delete-account.js';

const URL_ECHANGE = SUPABASE_URL + '/functions/v1/auth-firebase-exchange';
const URL_RPC = SUPABASE_URL + '/rest/v1/rpc/request_account_deletion';

const rep = (status, corps) => ({
  ok: status >= 200 && status < 300,
  status,
  json: async () => {
    if (corps === undefined) throw new SyntaxError('corps non JSON');
    return corps;
  },
});
const sessionOk = rep(200, { access_token: 'AT', refresh_token: 'RT', expires_in: 3600 });

// Chaque route rend une réponse, ou lève (panne réseau : `fetch` rejette).
function faux(routes) {
  const appels = [];
  const fetchImpl = async (url, init) => {
    appels.push({ url, init });
    const r = routes[url];
    if (r === undefined) throw new Error('appel inattendu : ' + url);
    if (r instanceof Error) throw r;
    return r;
  };
  return { fetchImpl, appels };
}

const demander = (routes) => {
  const f = faux(routes);
  return requestDeletion('FIREBASE_JWT', { fetchImpl: f.fetchImpl }).then((issue) => ({ issue, ...f }));
};

// ── La constante ────────────────────────────────────────────────────────────

test("la clé publique est bien injectée (pas le marqueur du dépôt)", () => {
  assert.match(SUPABASE_PUBLISHABLE_KEY, /^sb_publishable_[A-Za-z0-9_-]+$/);
  assert.match(SUPABASE_URL, /^https:\/\/[a-z0-9]+\.supabase\.co$/);
});

// ── Le chemin nominal et ce qu'il envoie ────────────────────────────────────

test('succès : rend l\'échéance de la base, dans la précision de Date', async () => {
  const { issue } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: rep(200, '2026-10-19T10:15:00.123456+00:00'),
  });
  assert.equal(issue.kind, 'scheduled');
  assert.equal(issue.executeAt.toISOString(), '2026-10-19T10:15:00.123Z');
});

test('succès : une échéance sans fraction de seconde', async () => {
  const { issue } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: rep(200, '2026-10-19T10:15:00+02:00'),
  });
  assert.equal(issue.kind, 'scheduled');
  assert.equal(issue.executeAt.toISOString(), '2026-10-19T08:15:00.000Z');
});

test("l'échange n'envoie que Content-Type et Authorization (la préflight CORS n'en autorise pas d'autres)", async () => {
  const { appels } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: rep(200, '2026-10-19T10:15:00+00:00'),
  });
  const echange = appels[0];
  assert.equal(echange.url, URL_ECHANGE);
  assert.equal(echange.init.method, 'POST');
  assert.deepEqual(Object.keys(echange.init.headers).map((k) => k.toLowerCase()).sort(), [
    'authorization',
    'content-type',
  ]);
  // La passerelle exige l'en-tête : la clé publique y passe (mesuré le 2026-09-19).
  assert.equal(echange.init.headers.Authorization, `Bearer ${SUPABASE_PUBLISHABLE_KEY}`);
  assert.deepEqual(JSON.parse(echange.init.body), { firebase_token: 'FIREBASE_JWT' });
});

test("la RPC : clé publique en apikey, SESSION de la personne en Authorization, corps vide", async () => {
  const { appels } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: rep(200, '2026-10-19T10:15:00+00:00'),
  });
  const rpc = appels[1];
  assert.equal(rpc.url, URL_RPC);
  assert.equal(rpc.init.method, 'POST');
  assert.equal(rpc.init.headers.apikey, SUPABASE_PUBLISHABLE_KEY);
  assert.equal(rpc.init.headers.Authorization, 'Bearer AT');
  assert.equal(rpc.init.body, '{}');
});

// ── Les refus de la base ────────────────────────────────────────────────────

for (const motif of MOTIFS_DE_REFUS) {
  test(`refus « ${motif} » : 400 + P0001, le motif est dans message`, async () => {
    const { issue } = await demander({
      [URL_ECHANGE]: sessionOk,
      [URL_RPC]: rep(400, { code: 'P0001', details: null, hint: null, message: motif }),
    });
    assert.deepEqual(issue, { kind: 'refused', reason: motif });
  });
}

test("un message P0001 inconnu ne s'affiche pas : unknown", async () => {
  const { issue } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: rep(400, { code: 'P0001', message: 'Utilisateur non authentifié: détail interne' }),
  });
  assert.equal(issue.kind, 'unknown');
});

test('un motif de refus sous un autre statut que 400 ne compte pas', async () => {
  const { issue } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: rep(500, { message: 'compte_plateforme' }),
  });
  assert.equal(issue.kind, 'unknown');
});

// ── Ce qui n'est pas un refus mais une panne ────────────────────────────────

test('RPC absente (404, PGRST202) : unavailable — le backend n\'est pas en ligne', async () => {
  const { issue } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: rep(404, { code: 'PGRST202', message: 'Could not find the function public.request_account_deletion' }),
  });
  assert.equal(issue.kind, 'unavailable');
});

for (const statut of [401, 403]) {
  test(`RPC ${statut} : session refusée`, async () => {
    const { issue } = await demander({
      [URL_ECHANGE]: sessionOk,
      [URL_RPC]: rep(statut, { code: '42501', message: 'Utilisateur non authentifié' }),
    });
    assert.equal(issue.kind, 'session');
  });
}

test("l'échange refuse (401 {error}) : session, et la RPC n'est PAS appelée", async () => {
  const { issue, appels } = await demander({
    [URL_ECHANGE]: rep(401, { error: 'Firebase token expired' }),
  });
  assert.equal(issue.kind, 'session');
  assert.equal(appels.length, 1);
});

test("l'échange répond 200 sans access_token : session, RPC non appelée", async () => {
  const { issue, appels } = await demander({ [URL_ECHANGE]: rep(200, { refresh_token: 'RT' }) });
  assert.equal(issue.kind, 'session');
  assert.equal(appels.length, 1);
});

test("panne réseau à l'échange : network", async () => {
  const { issue, appels } = await demander({ [URL_ECHANGE]: new TypeError('Failed to fetch') });
  assert.equal(issue.kind, 'network');
  assert.equal(appels.length, 1);
});

test('panne réseau à la RPC : network', async () => {
  const { issue } = await demander({
    [URL_ECHANGE]: sessionOk,
    [URL_RPC]: new TypeError('Failed to fetch'),
  });
  assert.equal(issue.kind, 'network');
});

// ── Jamais de succès sans date ──────────────────────────────────────────────

for (const [nom, corps] of [
  ['null', null],
  ['un objet', {}],
  ['une chaîne qui n\'est pas une date', 'ok'],
  ['un nombre', 5],
  ['une chaîne que V8 prendrait pour une date', 'garbage 5'],
  ['une date sans fuseau', '2026-10-19T10:15:00'],
  ['une date invalide', '2026-13-45T99:99:99+00:00'],
]) {
  test(`200 avec ${nom} : unknown, pas un succès à vide`, async () => {
    const { issue } = await demander({ [URL_ECHANGE]: sessionOk, [URL_RPC]: rep(200, corps) });
    assert.equal(issue.kind, 'unknown');
  });
}

test('200 avec un corps qui n\'est pas du JSON : unknown, sans lever', async () => {
  const { issue } = await demander({ [URL_ECHANGE]: sessionOk, [URL_RPC]: rep(200, undefined) });
  assert.equal(issue.kind, 'unknown');
});

test('400 avec un corps qui n\'est pas du JSON : unknown, sans lever', async () => {
  const { issue } = await demander({ [URL_ECHANGE]: sessionOk, [URL_RPC]: rep(400, undefined) });
  assert.equal(issue.kind, 'unknown');
});

test('500 : unknown', async () => {
  const { issue } = await demander({ [URL_ECHANGE]: sessionOk, [URL_RPC]: rep(500, { message: 'boom' }) });
  assert.equal(issue.kind, 'unknown');
});

// ── Les dates ───────────────────────────────────────────────────────────────

test('parseDeadline : refuse tout ce qui n\'est pas un horodatage complet', () => {
  assert.equal(parseDeadline(undefined), null);
  assert.equal(parseDeadline(''), null);
  assert.equal(parseDeadline('2026-10-19'), null);
  assert.ok(parseDeadline('2026-10-19T10:15:00Z') instanceof Date);
});

test('formatDeadline : dans la langue de la page', () => {
  const date = new Date('2026-10-19T12:00:00Z');
  assert.match(formatDeadline(date, 'fr'), /octobre 2026/);
  assert.match(formatDeadline(date, 'en'), /October .*2026/);
});

// ── Les deux pages ──────────────────────────────────────────────────────────

const lire = (chemin) => readFileSync(new URL('../../' + chemin, import.meta.url), 'utf8');
const PAGES = { fr: 'public/delete-account.html', en: 'public/delete-account-en.html' };
const html = { fr: lire(PAGES.fr), en: lire(PAGES.en) };
const messages = (page) =>
  JSON.parse(page.match(/<script type="application\/json" id="da-messages">([\s\S]*?)<\/script>/)[1]);

test('FR et EN portent exactement les mêmes clés de messages', () => {
  const fr = messages(html.fr);
  const en = messages(html.en);
  assert.deepEqual(Object.keys(fr).sort(), Object.keys(en).sort());
  assert.deepEqual(Object.keys(fr.signIn).sort(), Object.keys(en.signIn).sort());
  assert.deepEqual(Object.keys(fr.outcome).sort(), Object.keys(en.outcome).sort());
});

for (const [langue, page] of Object.entries(html)) {
  const m = messages(page);

  test(`${langue} : chaque issue de requestDeletion a son message`, () => {
    for (const cle of ['scheduled', 'unavailable', 'session', 'network', 'unknown', ...MOTIFS_DE_REFUS]) {
      assert.ok(m.outcome[cle]?.trim(), `${langue} : message « ${cle} » manquant`);
    }
    assert.ok(m.signIn.default?.trim());
  });

  test(`${langue} : le succès porte la date, rien d'autre n'a de trou à remplir`, () => {
    assert.match(m.outcome.scheduled, /\{date\}/);
    for (const [cle, texte] of Object.entries(m.outcome)) {
      if (cle !== 'scheduled') assert.doesNotMatch(texte, /\{/, `${langue} : « ${cle} » a un trou`);
    }
  });

  test(`${langue} : la langue et le mot de confirmation sont ceux de la page`, () => {
    assert.match(page, new RegExp(`<html lang="${langue}">`));
    assert.equal(m.lang, langue);
    // Le mot à taper est dit à la personne : dans l'invite et dans le champ.
    assert.ok(page.includes(`<strong>${m.confirmWord}</strong>`), `${langue} : consigne « ${m.confirmWord} » absente`);
    assert.ok(page.includes(`placeholder="${langue === 'fr' ? 'Tapez' : 'Type'} ${m.confirmWord}"`));
  });

  test(`${langue} : ce dont mount() a besoin dans le DOM`, () => {
    for (const id of [
      'deleteForm', 'email', 'password', 'confirmSection', 'confirmText',
      'confirmDeleteBtn', 'loader', 'formSection', 'errorMessage', 'successMessage',
    ]) {
      assert.ok(page.includes(`id="${id}"`), `${langue} : #${id} manquant`);
    }
  });

  test(`${langue} : la page ne supprime rien elle-même (ni Firestore ni deleteUser)`, () => {
    // Les commentaires expliquent pourquoi ces mots ont disparu : on ne les compte pas.
    const code = page.replace(/<!--[\s\S]*?-->/g, '');
    assert.doesNotMatch(code, /firebase-firestore/);
    assert.doesNotMatch(code, /\b(deleteUser|deleteDoc|writeBatch|getFirestore)\b/);
    assert.match(code, /from '\/assets\/delete-account\.js'/);
  });

  test(`${langue} : la session Firebase n'est jamais persistée`, () => {
    const code = page.replace(/<!--[\s\S]*?-->/g, '');
    assert.match(code, /initializeAuth\(app, \{ persistence: inMemoryPersistence \}\)/);
    assert.doesNotMatch(code, /\bgetAuth\b/);
  });

  test(`${langue} : ne promet plus l'effacement immédiat de « toutes » les données`, () => {
    const visible = page.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<[^>]+>/g, ' ');
    assert.doesNotMatch(visible, /définitivement effacées|permanently erased|Toutes vos données|All your data/);
    assert.match(visible, /30/);
  });
}
