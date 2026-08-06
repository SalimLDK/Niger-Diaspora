# Secrets de production — état et remise en ordre

Constat du 2026-08-03. Les valeurs listées ici sont celles **réellement
déployées** sur les Cloud Functions (visibles via `firebase functions:list --json`,
champ `environmentVariables`). Elles viennent de `functions/.env`, qui est
gitignoré.

Aucune vraie valeur ne figure dans ce document, et il ne faut pas en ajouter.

## Ce qui ne va pas

| Clé | État constaté | Conséquence |
|---|---|---|
| `STRIPE_WEBHOOK_SECRET` | placeholder `whsec_your_webhook_secret_here` | La vérification de signature échoue sur **tous** les webhooks Stripe. Les paiements ne sont jamais confirmés côté serveur. |
| `STRIPE_SECRET_KEY` | clé `sk_test_…` | La production tourne en mode test Stripe : aucun paiement réel n'aboutit. |
| `ENCRYPTION_KEY` | passphrase lisible et devinable | Le repli de chiffrement des messages est déchiffrable par quiconque devine la phrase. |
| `SUPABASE_SERVICE_KEY` | clé service role valide | Contourne toute RLS. Lisible par quiconque a un accès en lecture au projet Firebase. À traiter comme un secret de plus haut niveau. |
| `MYNITA_API_KEY`, `WAVE_API_KEY`, `VISA_DIRECT_API_KEY`, `MASTERCARD_SEND_API_KEY` | **absentes** | Voir la correction ci-dessous : les clients partenaires ne tournent pas « avec des identifiants vides », ils basculent en mode simulé. |

Un garde a été ajouté côté code (`isPlaceholderSecret()` dans
`functions/index.js`) : un secret laissé à sa valeur d'exemple provoque
désormais une erreur explicite dans les logs au lieu d'un échec silencieux plus
loin dans la chaîne. Il ne remplace pas la correction des valeurs.

## Inventaire complet (2026-08-05)

Le code backend lit **25** variables d'environnement. `functions/.env` en
contient **6**. Les 19 autres sont absentes — mais toutes n'ont pas la même
conséquence, et il a fallu lire chaque garde pour le savoir.

| Clé absente | Ce qui se passe réellement |
|---|---|
| `GCLOUD_PROJECT`, `FIREBASE_STORAGE_BUCKET` | Fournies par le runtime Cloud Functions. Rien à faire. |
| `MYNITA_*`, `WAVE_*`, `VISA_DIRECT_*`, `MASTERCARD_SEND_*` | `PARTNER_MOCK_MODE !== "false"` : sans la variable, le mode **simulé** est actif par défaut. Les clients ne partent donc pas en ligne avec des identifiants vides — ils simulent. Les paiements partenaires sont fictifs, pas cassés. |
| `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_SERVER_URL` | Repli prévu sur `functions.config().livekit`, **mais cette config est vide** (`functions:config:get` → `{}`). Les fonctions échouent proprement en journalisant « LiveKit API credentials not configured » : la génération de jetons pour les salons audio et les podcasts ne marche pas. |
| `ADMIN_API_KEY` | Échoue **fermé** : `!adminKey` renvoie 401 à tout le monde. L'endpoint d'administration est donc inaccessible, ce qui est le bon défaut. |
| `STRIPE_CONNECT_WEBHOOK_SECRET` | Échoue **fermé** : 500 explicite. |
| `REVENUECAT_WEBHOOK_AUTH` | Échouait **OUVERT** — voir ci-dessous. Corrigé le 2026-08-05. |

### 🔴 `revenueCatWebhook` acceptait n'importe qui

Le garde s'écrivait `if (authHeader) { … }` : variable absente, **aucune
vérification**. Or `REVENUECAT_WEBHOOK_AUTH` n'existe que dans `.env.example`.

L'endpoint est public
(`https://us-central1-diaspo-niger.cloudfunctions.net/revenueCatWebhook`,
déployé le 2026-07-19) et le corps de la fonction écrit
`revenueCat.subscriptionStatus = "active"` avec les entitlements et la date
d'expiration reçus, sur le compte dont l'`app_user_id` figure dans la requête —
plus `hasRevenueCatPodcastPremium` sur `creatorProfiles`. N'importe qui pouvant
atteindre l'URL pouvait donc s'offrir un abonnement premium, ou en offrir un.

Même classe que le placeholder Stripe, mais dans l'autre sens : celui-ci
laissait passer au lieu de tout refuser.

**Corrigé** : refus en 500 tant que le secret n'est pas configuré, puis
comparaison à temps constant. `firebase functions:log --only revenueCatWebhook`
ne montre **aucun appel** — ni trafic légitime à casser, ni trace d'abus.

Le correctif attend un déploiement ciblé :
`firebase deploy --only functions:revenueCatWebhook`.

## Procédure

À faire par Salim — je ne saisis pas de vraies clés, et elles ne doivent
transiter ni par le dépôt ni par une conversation.

### 1. Stripe

1. Dashboard Stripe → **Developers → API keys**, en mode **Live**. Copier la
   clé secrète `sk_live_…`.
2. Dashboard Stripe → **Developers → Webhooks** → l'endpoint
   `https://us-central1-diaspo-niger.cloudfunctions.net/stripeWebhook`
   (le créer s'il n'existe pas, événements `payment_intent.succeeded` et
   `payment_intent.payment_failed`). Copier le **signing secret** `whsec_…`.
3. Reporter les deux dans `functions/.env` :

   ```
   STRIPE_SECRET_KEY=sk_live_…
   STRIPE_WEBHOOK_SECRET=whsec_…
   ```

4. Côté application, la clé publiable passe par `--dart-define` et non par
   `.env` :

   ```
   flutter build apk --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_…
   ```

   Sans ça, `AppConfig.stripePublishableKey` retombe sur la clé de test codée en
   dur dans `lib/core/constants/app_config.dart`.

### 2. ENCRYPTION_KEY

Générer une clé de 32 octets et remplacer la passphrase :

```bash
openssl rand -base64 32
```

⚠️ **Changer cette clé rend illisibles les messages déjà chiffrés avec
l'ancienne.** À faire en connaissance de cause, ou prévoir une bascule à double
clé (déchiffrer avec l'ancienne, rechiffrer avec la nouvelle).

### 3. Clés partenaires

`functions/partners/` attend `MYNITA_API_KEY`, `WAVE_API_KEY`,
`VISA_DIRECT_API_KEY`, `MASTERCARD_SEND_API_KEY`. Tant qu'elles sont absentes,
`PARTNER_MOCK_MODE` doit rester à sa valeur par défaut (mode simulé) — le
passer à `false` avec des clés vides ferait partir de vraies requêtes non
authentifiées.

### 4. SUPABASE_SERVICE_KEY

Rotation depuis le dashboard Supabase → **Settings → API → service_role →
Rotate**. Reporter la nouvelle valeur dans `functions/.env` puis redéployer.
Toute autre intégration utilisant cette clé casse à la rotation : les recenser
avant.

### 5. Déploiement

`firebase deploy --only functions` republie `functions/.env` vers **toutes** les
fonctions. Corriger le fichier **avant** de déployer, sinon les valeurs fautives
sont reconduites.

Ne jamais ajouter `--force` : cela supprimerait `sendMessagePush`, encore
appelée par les APK déjà installés.

## Vérification après coup

```bash
npx firebase functions:log --only stripeWebhook -n 20
```

Un webhook accepté ne doit plus produire ni « Webhook secret not configured »
ni « signature verification failed ».
