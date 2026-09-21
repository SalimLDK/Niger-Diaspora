// Banc : le bloc `data` du message FCM construit par `send-push`.
//
//   node --experimental-strip-types tools/rules_tests/send_push_donnees.mjs
//
// Il importe le module MÊME que la fonction déployée
// (supabase/functions/send-push/donnees_fcm.ts) : pas de copie qui pourrait
// diverger. Node 22 lit le TypeScript avec `--experimental-strip-types` ; pas
// besoin de Deno.
//
// Ce qu'il prouve : une clé de `notifications.data` ne peut plus imposer le
// `type` que l'app lit à la réception — c'est ce qui permettait de faire
// ouvrir l'écran d'appel entrant avec un nom d'appelant choisi. Et que rien
// d'autre ne change pour les messages légitimes.
//
// Condition : « 0 ÉCHEC ». Montré en échec le 2026-09-21 en remettant les clés
// réservées AVANT la boucle, comme avant.

import { construireDonneesFcm, CLES_RESERVEES } from '../../supabase/functions/send-push/donnees_fcm.ts';

let echecs = 0;
function cas(nom, ok, detail = '') {
  if (!ok) echecs++;
  console.log(`${ok ? 'OK    ' : 'ÉCHEC '} ${nom}${detail ? `  — ${detail}` : ''}`);
}

// ── 1. La falsification ─────────────────────────────────────────────────────
{
  const d = construireDonneesFcm({
    type: 'friendRequest',
    title: 'Nouvelle demande d\'ami',
    body: 'Alice souhaite vous ajouter en ami',
    targetId: 'alice',
    rawData: {
      type: 'incoming_call',
      title: 'Votre compte sera suspendu',
      body: 'Confirmez vos informations',
      targetId: 'autre-fiche',
      click_action: 'AUTRE_ACTIVITE',
      callId: 'c',
      callerName: 'Service Sécurité',
    },
  });
  cas('LA FAILLE — data.type ne remplace plus le type', d.type === 'friendRequest', `type=${d.type}`);
  cas('LA FAILLE — data.title / data.body ne remplacent plus le texte',
    d.title === 'Nouvelle demande d\'ami' && d.body === 'Alice souhaite vous ajouter en ami',
    `${d.title} · ${d.body}`);
  cas('targetId et click_action restent ceux du serveur',
    d.targetId === 'alice' && d.click_action === 'FLUTTER_NOTIFICATION_CLICK',
    `${d.targetId} · ${d.click_action}`);
  // Les autres clés passent : ce module ne filtre pas, il ne fait que donner
  // le dernier mot aux clés réservées. Le filtrage des émetteurs non fiables
  // se fait en amont (create_user_notification, liste blanche).
  cas('les clés non réservées sont recopiées', d.callerName === 'Service Sécurité');
}

// ── 2. Non-régression : un message de discussion réel ───────────────────────
{
  const rawData = {
    type: 'message',
    conversationId: 'conv-1',
    messageId: 'msg-1',
    senderName: 'Alice',
    senderPhotoUrl: 'https://exemple.invalid/a.png',
    targetId: 'conv-1',
    conversationType: 'direct',
  };
  const d = construireDonneesFcm({
    type: 'message', title: 'Alice', body: 'Salut', targetId: 'conv-1', rawData,
  });
  const attendu = { ...rawData, type: 'message', title: 'Alice', body: 'Salut',
    targetId: 'conv-1', click_action: 'FLUTTER_NOTIFICATION_CLICK' };
  const egal = JSON.stringify(Object.entries(d).sort()) === JSON.stringify(Object.entries(attendu).sort());
  cas('un message de discussion ressort à l\'identique', egal);
}

// ── 3. Mise en forme FCM ────────────────────────────────────────────────────
{
  const d = construireDonneesFcm({
    type: 't', title: 'x', body: 'y', targetId: 'z',
    rawData: { nul: null, absent: undefined, n: 3, b: true, o: { a: 1 }, l: [1, 2] },
  });
  cas('null et undefined sont omis', !('nul' in d) && !('absent' in d));
  cas('scalaires en chaîne, objets et tableaux en JSON',
    d.n === '3' && d.b === 'true' && d.o === '{"a":1}' && d.l === '[1,2]');
  cas('toutes les valeurs sont des chaînes (FCM l\'exige)',
    Object.values(d).every((v) => typeof v === 'string'));
  cas('les cinq clés réservées sont toujours présentes',
    CLES_RESERVEES.every((k) => typeof d[k] === 'string'));
}

console.log(`\n>>> ${echecs} ÉCHEC(S)`);
process.exit(echecs ? 1 : 0);
