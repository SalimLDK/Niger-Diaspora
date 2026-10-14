// Banc : quand `send-push` retire un jeton de `users.fcm_tokens`.
//
//   node --experimental-strip-types tools/rules_tests/send_push_jeton_mort.mjs
//
// Il importe le module MÊME que la fonction déployée
// (supabase/functions/send-push/jeton_mort.ts).
//
// Ce qu'il prouve : un message refusé pour sa TAILLE ou sa forme ne coûte
// plus ses jetons au destinataire ; un jeton réellement mort part toujours.
// Les réponses sont celles que documente FCM v1 (`messages.send`, codes
// d'erreur). Condition : « 0 ÉCHEC ». Montré en échec le 2026-10-14 contre
// l'ancienne règle (`/UNREGISTERED|INVALID_ARGUMENT/`) : les cas 1 et 2
// tombent.

import { estJetonMort } from '../../supabase/functions/send-push/jeton_mort.ts';

let echecs = 0;
function cas(n, nom, attendu, obtenu) {
  const ok = attendu === obtenu;
  if (!ok) echecs++;
  console.log(`${ok ? 'OK    ' : 'ÉCHEC '} ${n}. ${nom}  — attendu ${attendu ? 'retiré' : 'gardé'}`);
}

const err = (status, message, details = []) =>
  JSON.stringify({ error: { code: 400, message, status, details } });

cas(1, 'message trop gros', false,
  estJetonMort(400, err('INVALID_ARGUMENT', 'Request contains an invalid argument.',
    [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'INVALID_ARGUMENT' },
     { '@type': 'type.googleapis.com/google.rpc.BadRequest',
       fieldViolations: [{ field: 'message', description: 'Message is too big. Data payload size limit is 4096 bytes.' }] }])));
cas(2, 'champ data mal formé', false,
  estJetonMort(400, err('INVALID_ARGUMENT', 'Invalid value at \'message.data[0].value\' (TYPE_STRING)')));
cas(3, 'jeton désinscrit (UNREGISTERED)', true,
  estJetonMort(404, err('NOT_FOUND', 'Requested entity was not found.',
    [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED' }])));
cas(4, 'jeton invalide (INVALID_ARGUMENT qui nomme le jeton)', true,
  estJetonMort(400, err('INVALID_ARGUMENT', 'The registration token is not a valid FCM registration token')));
cas(5, 'jeton invalide (violation sur message.token)', true,
  estJetonMort(400, err('INVALID_ARGUMENT', 'Request contains an invalid argument.',
    [{ '@type': 'type.googleapis.com/google.rpc.BadRequest',
       fieldViolations: [{ field: 'message.token', description: 'Invalid registration token' }] }])));
cas(6, 'quota dépassé (429)', false,
  estJetonMort(429, err('RESOURCE_EXHAUSTED', 'Quota exceeded', [{ errorCode: 'QUOTA_EXCEEDED' }])));
cas(7, 'panne FCM (503)', false,
  estJetonMort(503, err('UNAVAILABLE', 'The service is currently unavailable.')));

console.log(`\n>>> ${echecs} ÉCHEC(S)`);
process.exit(echecs ? 1 : 0);
