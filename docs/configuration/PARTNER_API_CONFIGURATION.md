# Configuration des APIs Partenaires

Ce document decrit comment configurer les APIs des partenaires de paiement (Mynita, Wave, Visa Direct, Mastercard Send).

## Variables d'environnement

Ajoutez les variables suivantes dans `functions/.env` :

```bash
# ============ MODE MOCK ============
# true = simulation (pas d'appels API reels)
# false = production (appels API reels)
PARTNER_MOCK_MODE=true

# ============ MYNITA ============
MYNITA_API_URL=https://api.mynita.com/v1
MYNITA_API_KEY=votre_cle_api_mynita
MYNITA_WEBHOOK_SECRET=votre_secret_webhook_mynita

# ============ WAVE ============
WAVE_API_URL=https://api.wave.com/v1
WAVE_API_KEY=votre_cle_api_wave
WAVE_WEBHOOK_SECRET=votre_secret_webhook_wave

# ============ VISA DIRECT ============
VISA_DIRECT_URL=https://sandbox.api.visa.com/visadirect
VISA_DIRECT_API_KEY=votre_cle_api_visa
VISA_DIRECT_SHARED_SECRET=votre_secret_visa

# ============ MASTERCARD SEND ============
MASTERCARD_SEND_URL=https://sandbox.api.mastercard.com/send
MASTERCARD_SEND_API_KEY=votre_cle_api_mastercard
MASTERCARD_SEND_CONSUMER_KEY=votre_consumer_key_mastercard
```

## Configuration Firebase Functions

Pour deployer avec les secrets :

```bash
# Definir les secrets dans Firebase
firebase functions:secrets:set MYNITA_API_KEY
firebase functions:secrets:set MYNITA_WEBHOOK_SECRET
firebase functions:secrets:set WAVE_API_KEY
firebase functions:secrets:set WAVE_WEBHOOK_SECRET
firebase functions:secrets:set VISA_DIRECT_API_KEY
firebase functions:secrets:set MASTERCARD_SEND_API_KEY

# Deployer les fonctions
firebase deploy --only functions
```

## Structure des fichiers partenaires

```
functions/
├── partners/
│   ├── index.js          # Factory et exports
│   ├── mynita.js         # Client Mynita (debit + credit)
│   ├── wave.js           # Client Wave (debit + credit)
│   ├── card.js           # Client Visa Direct / Mastercard Send
│   └── fees.js           # Configuration des frais
└── index.js              # Cloud Functions principales
```

## Flux de paiement

### 1. Debit (prelevement expediteur)

**Providers supportes :** Mynita, Wave

```
Client Flutter                    Firebase Functions
     |                                   |
     |-- Cree debit_request ----------->|
     |                                   |-- Appelle API Mynita/Wave
     |                                   |<-- Reponse initiale
     |<-- Ecoute changement status -----|
     |                                   |
     |                    [Webhook Mynita/Wave]
     |                                   |-- Confirme debit
     |<-- Status: "debiting" -> "processing"
```

### 2. Credit (envoi au beneficiaire)

**Providers supportes :** Mynita, Wave, Card (Visa Direct/Mastercard Send)

```
Firebase Functions                    Partenaire
     |                                   |
     |-- Transaction status = "processing"
     |-- Detecte type beneficiaire ------>
     |                                   |
     | [Mynita/Wave]                     |
     |-- Appelle API credit ------------>|
     |<-- Reference transaction ---------|
     |-- Status: "sending"               |
     |                                   |
     |                    [Webhook]      |
     |<-- Confirmation credit -----------|
     |-- Status: "completed"             |
     |                                   |
     | [Carte Visa/Mastercard]           |
     |-- Appelle Visa Direct / MC Send ->|
     |<-- Confirmation instantanee ------|
     |-- Status: "completed"             |
```

## Webhooks

### URLs des webhooks (a configurer chez les partenaires)

```
Mynita: https://[REGION]-[PROJECT_ID].cloudfunctions.net/mynitaWebhook
Wave:   https://[REGION]-[PROJECT_ID].cloudfunctions.net/waveWebhook
```

### Format attendu des webhooks

**Mynita:**
```json
{
  "event": "debit.success" | "debit.failed" | "credit.success" | "credit.failed",
  "transactionId": "MYN_xxx",
  "ourReference": "transaction_id_firestore",
  "amount": 65000,
  "currency": "XOF",
  "status": "success" | "failed",
  "failureReason": "optional error message"
}
```

**Wave:**
```json
{
  "event": "payment.completed" | "payment.failed",
  "id": "WAVE_xxx",
  "reference": "transaction_id_firestore",
  "amount": 65000,
  "currency": "XOF",
  "status": "completed" | "failed",
  "failure_reason": "optional error message"
}
```

## Frais des partenaires

Les frais sont configures dans `functions/partners/fees.js` :

| Partenaire | Operation | Pourcentage | Minimum | Maximum |
|------------|-----------|-------------|---------|---------|
| Mynita     | Debit     | 1%          | 100 XOF | 5000 XOF |
| Mynita     | Credit    | 0.5%        | 50 XOF  | 2500 XOF |
| Wave       | Debit     | 1.5%        | 150 XOF | 7500 XOF |
| Wave       | Credit    | 0.5%        | 50 XOF  | 2500 XOF |
| Card       | Credit    | 2%          | 500 XOF | 10000 XOF |

## Passer en production

1. **Obtenir les credentials API** aupres de chaque partenaire
2. **Configurer les secrets Firebase** avec les vraies cles
3. **Mettre `PARTNER_MOCK_MODE=false`**
4. **Tester en sandbox** avant de passer en production
5. **Deployer** : `firebase deploy --only functions`

## Tests

### Test en mode mock

```bash
# Le mode mock simule les reponses API
# Utile pour tester le flux complet sans credentials

# Dans functions/.env
PARTNER_MOCK_MODE=true
```

### Test des webhooks (curl)

```bash
# Simuler un webhook Mynita
curl -X POST https://[REGION]-[PROJECT].cloudfunctions.net/mynitaWebhook \
  -H "Content-Type: application/json" \
  -H "X-Mynita-Signature: test_signature" \
  -d '{
    "event": "credit.success",
    "transactionId": "MYN_123",
    "ourReference": "firestore_transaction_id",
    "status": "success"
  }'
```

## Troubleshooting

### Erreur "Unsupported debit provider"
- Verifiez que le provider est bien "mynita" ou "wave" (minuscules)

### Erreur "Invalid webhook signature"
- Verifiez que `MYNITA_WEBHOOK_SECRET` / `WAVE_WEBHOOK_SECRET` sont corrects

### Transaction bloquee en "debiting"
- Le webhook de confirmation n'a pas ete recu
- Verifiez les logs Firebase Functions
- Verifiez la configuration webhook chez le partenaire

### Carte rejetee
- Verifiez que la carte supporte Visa Direct / Mastercard Send
- Certaines cartes (prepayees, virtuelles) ne supportent pas push-to-card
