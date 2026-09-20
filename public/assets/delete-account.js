// Demande de suppression de compte, côté site (delete-account.html et -en).
//
// La page ne supprime plus rien elle-même. Elle demande à Supabase de le faire :
//
//   1. connexion Firebase (dans la page : identifiant + mot de passe) ;
//   2. `auth-firebase-exchange` : le jeton Firebase contre une session Supabase ;
//   3. `request_account_deletion()` : le compte est désactivé tout de suite, la
//      suppression définitive est fixée à 30 jours (la base rend l'échéance).
//
// C'est la même RPC que celle de l'application. Elle est idempotente : une
// demande déjà en cours rend sa date sans la repousser, la page l'affiche
// comme un succès. La suppression réelle est faite plus tard par la fonction
// planifiée `finalizeAccountDeletions` — jamais depuis ici.
//
// ⚠️ LA PAGE NE PEUT PAS ÊTRE PUBLIÉE AVANT LE BACKEND. Sans la migration
// 20260918224100 la RPC répond 404 (la page le dit, `unavailable`) ; sans la
// fonction planifiée les demandes s'empilent et rien n'est supprimé au bout
// des 30 jours, alors que la page le promet.
//
// L'URL et la clé sont publiques par conception (la clé part déjà dans chaque
// APK) : ce qui protège les données, c'est la RLS, et la RPC n'est accordée
// qu'au rôle `authenticated`.

export const SUPABASE_URL = 'https://zyrfkcjjrhddpfxcgezo.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_U7u_QEnnyMfTKfQlvILr5Q_gESSkv1G';

// Les motifs de refus que la base énonce (`RAISE EXCEPTION '<motif>'`, code
// P0001, que PostgREST rend en 400 avec le motif dans `message`). Tout autre
// message reste inconnu : il n'a pas à s'afficher.
export const MOTIFS_DE_REFUS = ['compte_plateforme', 'obligations_financieres', 'suppression_deja_engagee'];

// `timestamptz` tel que PostgREST le sérialise. Exigé AVANT de le donner à
// `Date` : l'analyseur de V8 accepte « garbage 5 » (année 2001) — une réponse
// sans date ne doit jamais passer pour un succès.
const HORODATAGE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}(:?\d{2})?)$/;

export function parseDeadline(value) {
  if (typeof value !== 'string' || !HORODATAGE.test(value)) return null;
  // PostgREST rend des microsecondes ; `Date` n'en veut que trois (Safari est strict).
  const date = new Date(value.replace(/(\.\d{3})\d+/, '$1'));
  return Number.isNaN(date.getTime()) ? null : date;
}

// Date locale, comme l'application (`parseLocalDate`) : « 19 octobre 2026 ».
export function formatDeadline(date, lang) {
  return date.toLocaleDateString(lang, { day: 'numeric', month: 'long', year: 'numeric' });
}

// Issues de la demande. `scheduled` et `refused` sont définitives ; les autres
// se retentent (la RPC est idempotente : rejouer ne peut pas faire de mal).
//
//   scheduled    { kind, executeAt: Date }
//   refused      { kind, reason: <motif de MOTIFS_DE_REFUS> }
//   unavailable  la RPC n'existe pas (404) — backend pas encore en ligne
//   session      l'échange ou la RPC ont refusé la session (401/403)
//   network      la requête n'a pas abouti
//   unknown      réponse non reconnue : pas de succès sans date
export async function requestDeletion(
  idToken,
  { fetchImpl = globalThis.fetch.bind(globalThis), url = SUPABASE_URL, key = SUPABASE_PUBLISHABLE_KEY } = {},
) {
  // `fetch` ne rejette que sur une panne réseau : c'est la seule chose qu'on
  // range sous `network`, une vraie exception ailleurs ne doit pas s'y cacher.
  const appeler = async (chemin, init) => {
    try {
      return await fetchImpl(url + chemin, { method: 'POST', ...init });
    } catch {
      return null;
    }
  };
  const lireJson = async (reponse) => {
    try {
      return await reponse.json();
    } catch {
      return null;
    }
  };

  // Seuls `Content-Type` et `Authorization` : la préflight CORS de la fonction
  // n'autorise rien d'autre (`apikey` ou `x-client-info` la feraient échouer
  // dans le navigateur). La passerelle exige l'en-tête `Authorization` — mesuré
  // le 2026-09-19 : sans lui, 401 UNAUTHORIZED_NO_AUTH_HEADER — et accepte la
  // clé publique à cet endroit.
  const echange = await appeler('/functions/v1/auth-firebase-exchange', {
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({ firebase_token: idToken }),
  });
  if (!echange) return { kind: 'network' };
  const session = echange.ok ? await lireJson(echange) : null;
  if (!session || typeof session.access_token !== 'string') return { kind: 'session' };

  // PostgREST : `apikey` pour la passerelle, la session de la personne en
  // `Authorization` — c'est elle que `firebase_uid()` lit dans la RPC.
  const rpc = await appeler('/rest/v1/rpc/request_account_deletion', {
    headers: {
      'Content-Type': 'application/json',
      apikey: key,
      Authorization: `Bearer ${session.access_token}`,
    },
    body: '{}',
  });
  if (!rpc) return { kind: 'network' };
  const corps = await lireJson(rpc);

  if (rpc.ok) {
    const executeAt = parseDeadline(corps);
    return executeAt ? { kind: 'scheduled', executeAt } : { kind: 'unknown' };
  }
  if (rpc.status === 404) return { kind: 'unavailable' };
  if (rpc.status === 401 || rpc.status === 403) return { kind: 'session' };
  const motif = corps && typeof corps === 'object' ? corps.message : undefined;
  if (rpc.status === 400 && MOTIFS_DE_REFUS.includes(motif)) return { kind: 'refused', reason: motif };
  return { kind: 'unknown' };
}

// Les textes vivent dans la page (bloc JSON `#da-messages`), pas ici : une page
// par langue, la même logique. `test/` vérifie que les deux blocs disent la
// même chose.
export function mount({ signIn, signOut, doc = document }) {
  const messages = JSON.parse(doc.getElementById('da-messages').textContent);
  const $ = (id) => doc.getElementById(id);
  const form = $('deleteForm');
  const confirmSection = $('confirmSection');
  const confirmText = $('confirmText');
  const confirmBtn = $('confirmDeleteBtn');
  const loader = $('loader');
  const formSection = $('formSection');
  const errorBox = $('errorMessage');
  const successBox = $('successMessage');

  let user = null;
  let occupe = false;

  const montrer = (element, oui) => {
    element.style.display = oui ? 'block' : 'none';
  };
  const effacerMessages = () => {
    montrer(errorBox, false);
    montrer(successBox, false);
  };
  // Les messages restent affichés jusqu'à la tentative suivante : un refus
  // porte une consigne (« écrivez à… ») qu'on ne peut pas laisser s'évaporer.
  const erreur = (texte) => {
    errorBox.textContent = texte;
    montrer(errorBox, true);
    montrer(successBox, false);
  };
  const succes = (texte) => {
    successBox.textContent = texte;
    montrer(successBox, true);
    montrer(errorBox, false);
  };
  const charge = (oui) => {
    montrer(loader, oui);
    montrer(formSection, !oui);
  };
  // Plus de `deleteUser` : rien ne ferme la session Firebase à notre place.
  const terminer = async () => {
    user = null;
    try {
      await signOut();
    } catch {
      // Sans conséquence : la persistance est en mémoire, la page suffit à l'effacer.
    }
  };
  const motConfirme = () =>
    confirmText.value.trim().toLocaleUpperCase(messages.lang) === messages.confirmWord;

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    effacerMessages();
    charge(true);
    try {
      user = await signIn($('email').value.trim(), $('password').value);
    } catch (e2) {
      charge(false);
      const code = String(e2?.code ?? '').replace(/^auth\//, '');
      // Firebase ne distingue plus « inconnu » de « mauvais mot de passe » quand
      // la protection contre l'énumération est active : on n'en fait pas plus.
      const cle = ['user-not-found', 'wrong-password'].includes(code) ? 'invalid-credential' : code;
      erreur(messages.signIn[cle] ?? messages.signIn.default);
      return;
    }
    $('password').value = '';
    charge(false);
    montrer(form, false);
    montrer(confirmSection, true);
    confirmBtn.disabled = !motConfirme();
    confirmText.focus();
  });

  confirmText.addEventListener('input', () => {
    confirmBtn.disabled = !motConfirme();
  });

  confirmBtn.addEventListener('click', async () => {
    if (occupe || !motConfirme()) return;
    if (!user) {
      erreur(messages.outcome.session);
      return;
    }
    occupe = true;
    effacerMessages();
    charge(true);

    let idToken = null;
    try {
      idToken = await user.getIdToken();
    } catch {
      // Session Firebase expirée : traité comme un refus de session.
    }
    const issue = idToken ? await requestDeletion(idToken) : { kind: 'session' };

    charge(false);
    if (issue.kind === 'scheduled') {
      montrer(formSection, false);
      succes(messages.outcome.scheduled.replace('{date}', formatDeadline(issue.executeAt, messages.lang)));
      await terminer();
    } else if (issue.kind === 'refused') {
      montrer(formSection, false);
      erreur(messages.outcome[issue.reason] ?? messages.outcome.unknown);
      await terminer();
    } else {
      // Rejouable : la confirmation reste affichée, la session Firebase gardée.
      erreur(messages.outcome[issue.kind] ?? messages.outcome.unknown);
    }
    occupe = false;
  });
}
