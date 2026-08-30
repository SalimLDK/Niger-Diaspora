// Configuration publique de l'application, servie depuis les secrets Supabase.
//
// But : pouvoir changer une cle sans republier d'APK. Ce n'est PAS un
// mecanisme de confidentialite -- tout ce que cet endpoint renvoie devient
// public, puisque quiconque possede l'app peut l'appeler. D'ou la liste
// blanche ci-dessous, qui ne contient que des valeurs deja publiques
// aujourd'hui (elles sont dans l'APK, dans AndroidManifest.xml ou dans
// google-services.json, tous extractibles).
//
// Les vrais secrets (SERVICE_ROLE_KEY, STRIPE_SECRET_KEY, TWILIO_*,
// FCM_SERVICE_ACCOUNT, PUSH_WEBHOOK_SECRET, ENCRYPTION_KEY, GIPHY/TENOR)
// ne doivent JAMAIS entrer dans cette liste. Les cles GIF passent par
// `gif-proxy`, qui les utilise sans jamais les rendre.
//
// La liste est fermee et ecrite en dur : ajouter un secret au projet ne peut
// pas l'exposer par accident.
const CLES_PUBLIQUES = [
  'GOOGLE_MAPS_API_KEY',
  'GOOGLE_WEB_CLIENT_ID',
  'GOOGLE_IOS_CLIENT_ID',
  'RECAPTCHA_SITE_KEY',
  'DEEP_LINK_BASE_URL',
  'LIVEKIT_SERVER_URL',
  'STRIPE_MERCHANT_IDENTIFIER',
  'IOS_BUNDLE_ID',
] as const

// Volontairement absent de la liste : les FIREBASE_*. `lib/firebase_options.dart`
// les porte en dur et `Firebase.initializeApp` s'execute avant que Supabase ne
// soit pret -- les servir ici laisserait croire qu'on peut les piloter, alors
// que rien ne les lirait.

Deno.serve((req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() })
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
    return jsonResponse(405, { success: false, error: 'Method Not Allowed' })
  }

  // Pas d'authentification exigee : la configuration est necessaire au
  // demarrage, avant toute connexion. C'est acceptable parce que la liste
  // blanche ne contient que du public -- et seulement pour cette raison.
  const config: Record<string, string> = {}
  for (const cle of CLES_PUBLIQUES) {
    const valeur = Deno.env.get(cle)
    if (valeur) config[cle] = valeur
  }

  return jsonResponse(200, { success: true, config })
})

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, content-type',
  }
}

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  })
}
