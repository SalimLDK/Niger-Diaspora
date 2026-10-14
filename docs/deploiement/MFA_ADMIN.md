# Second facteur obligatoire sur les comptes admin (TOTP)

Réponse au § 8 et au § 10 point 7 de `AUDIT_ADMIN_2026-10-14.md` : « pas de
second facteur pour les comptes admin ; un mot de passe hameçonné vaut le
panneau entier ». Cette note dit ce que Firebase Auth exige côté projet, ce
que Salim fait lui-même dans la console et par l'API, pourquoi TOTP et pas
SMS, et le parcours que le panneau impose (`lib/features/admin`).

## État relevé le 2026-10-14

Lu par l'API Identity Toolkit, pas supposé d'après la console (même recette
que pour relire un fournisseur Apple, `project_ios_publication`) :

```bash
GC="/c/Users/danko/AppData/Local/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd"
TOK=$("$GC" auth print-access-token | tr -d '\r')
curl -s -H "Authorization: Bearer $TOK" -H "X-Goog-User-Project: diaspo-niger" \
  "https://identitytoolkit.googleapis.com/admin/v2/projects/diaspo-niger/config"
```

| Champ | Valeur relevée | Ce que ça veut dire |
|---|---|---|
| `subtype` | `IDENTITY_PLATFORM` | **Le projet est déjà passé à Identity Platform.** Rien à acheter ni à activer de ce côté : c'est le préalable à tout multi-facteur, et il est fait. |
| `mfa.state` | `ENABLED` | Le multi-facteur est allumé au niveau du projet. |
| `mfa.enabledProviders` | `["PHONE_SMS"]` | **Seul le SMS est activé.** Aucun `providerConfigs` avec `totpProviderConfig` : **TOTP n'est pas activé**, l'enrôlement échouerait en `operation-not-allowed`. |
| `signIn.email` | `enabled`, mot de passe requis | Premier facteur accepté par Firebase pour un défi MFA (e-mail + mot de passe, ou fournisseur fédéré comme Google). |
| `authorizedDomains` | `localhost`, `diaspo-niger.web.app`, `diasponiger.com`, `diaspo-niger-admin.web.app`, … | Déjà suffisant : TOTP n'a pas de domaine à autoriser en plus. |
| `blockingFunctions` | `{}` | Aucune fonction bloquante. Non requise ici. |

Sans `X-Goog-User-Project`, l'appel répond 403 « requires a quota project »,
qui se lit à tort comme une API désactivée. La réponse contient aussi un
`clientSecret` OAuth et un numéro de téléphone de test : ne pas la coller
ailleurs.

Combien de comptes portent déjà un facteur (SMS) : **non mesuré** — la
lecture des comptes en production par l'Admin SDK a été refusée par le
classificateur de permissions de cette session. À relever avant d'activer
TOTP, pour savoir si retirer `PHONE_SMS` casserait une connexion existante :

```js
// depuis functions/ (firebase-admin et la clé de service y sont)
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./diaspo-niger-firebase-adminsdk-fbsvc-a3182736fb.json')) });
let token, total = 0, avec = 0;
do {
  const p = await admin.auth().listUsers(1000, token);
  for (const u of p.users) { total++; if (u.multiFactor?.enrolledFactors?.length) avec++; }
  token = p.pageToken;
} while (token);
console.log({ total, avec });
```

## Ce que Firebase Auth multi-facteur exige côté projet

1. **Identity Platform** (fait). Le multi-facteur n'existe pas dans Firebase
   Auth « de base » ; il faut le projet en « Firebase Authentication with
   Identity Platform », ce qui exige le plan Blaze (le projet y est, les
   Cloud Functions tournent). Le passage se fait depuis la console Firebase
   (Authentication → Paramètres → « Passer à Identity Platform ») ou depuis
   la console Google Cloud (Identity Platform → Activer). **Déjà fait ici**,
   relevé ci-dessus.

2. **Le coût.** Identity Platform facture à l'**utilisateur actif mensuel**
   (MAU), tarif public au 2026-10-14, à revérifier sur
   <https://cloud.google.com/identity-platform/pricing> :

   | Fournisseurs | Gratuit jusqu'à | Ensuite |
   |---|---|---|
   | E-mail/mot de passe, Google, Apple, téléphone, anonyme, custom (« niveau 1 ») | 49 999 MAU / mois | 0,0055 $ par MAU de 50 000 à 99 999, puis dégressif (0,0046 $, 0,0032 $, 0,0025 $) |
   | SAML / OIDC (« niveau 2 ») | 49 MAU | 0,015 $ par MAU |
   | SMS (connexion par téléphone **et** second facteur SMS) | rien | par message, tarif selon le pays de destination ; aucun quota gratuit sous Identity Platform |
   | **TOTP** | — | **aucun coût à l'usage** |

   L'app a 54 comptes (relevé du 2026-09-21) : le niveau 1 reste à zéro très
   loin. Le seul poste qui bouge avec le multi-facteur est le SMS — et TOTP
   l'évite entièrement.

3. **Activer TOTP sur le projet.** C'est la seule étape manquante, et c'est
   Salim qui la fait (elle modifie la configuration de production). Deux
   voies :

   - **Console Firebase** : Authentication → Paramètres (Settings) →
     « Authentification multifacteur » → activer l'authentificateur TOTP s'il
     y est proposé. Au 2026-10-14 la documentation Firebase ne décrit que
     l'Admin SDK et l'API pour TOTP ; si la bascule n'y est pas, prendre la
     voie suivante.
   - **API** (sûre, idempotente, vérifiable) : un `PATCH` sur la même
     ressource que la lecture, en ne touchant que `mfa`. **Garder
     `PHONE_SMS` dans `enabledProviders`** tant que le relevé ci-dessus n'a
     pas dit qu'aucun compte n'en dépend — l'enlever désactiverait le second
     facteur SMS de qui l'aurait enrôlé.

     ```bash
     curl -s -X PATCH -H "Authorization: Bearer $TOK" \
       -H "X-Goog-User-Project: diaspo-niger" -H "Content-Type: application/json" \
       "https://identitytoolkit.googleapis.com/admin/v2/projects/diaspo-niger/config?updateMask=mfa" \
       -d '{"mfa":{"state":"ENABLED","enabledProviders":["PHONE_SMS"],
            "providerConfigs":[{"state":"ENABLED","totpProviderConfig":{"adjacentIntervals":5}}]}}'
     ```

     `adjacentIntervals: 5` : tolérance de ±5 fenêtres de 30 s sur l'horloge
     du téléphone (la valeur maximale, recommandée par Firebase). Relire
     ensuite avec le `GET` ci-dessus : `mfa.providerConfigs[0].state` doit
     valoir `ENABLED`.

4. **Rien d'autre.** TOTP n'a besoin ni de reCAPTCHA (le SMS, si), ni de
   domaine autorisé supplémentaire, ni de fonction bloquante, ni de clé
   serveur : le secret est généré par Firebase et prouvé par le code.

5. **Le compte qui enrôle doit s'être connecté récemment** (Firebase exige
   une session de moins de 5 min pour `getSession()`, sinon
   `requires-recent-login`). Le parcours enrôle **juste après** la connexion,
   donc le cas ne se présente qu'en tapant `/dashboard` avec une vieille
   session : l'écran le dit et propose de se reconnecter.

## Pourquoi TOTP et pas SMS

- **Pas de coût par message.** Le SMS est facturé à chaque défi, à un tarif
  par pays ; le Niger n'est pas dans les pays les moins chers, et chaque
  connexion au panneau en enverrait un.
- **Pas de numéro à collecter ni à stocker.** Un facteur SMS lie un numéro de
  téléphone au compte, dans Firebase Auth — une donnée personnelle de plus à
  déclarer (la fiche Play a déjà été refusée cinq fois sur la divulgation des
  données). TOTP ne stocke qu'un secret partagé côté Firebase.
- **Pas de SIM swap, pas de réseau mobile requis.** Le code se calcule hors
  ligne dans l'application d'authentification (Google Authenticator, Aegis,
  1Password…). Un SMS intercepté ou dérouté vaut le panneau.
- **Pas de reCAPTCHA à poser.** Le défi SMS sur le web passe par un
  `RecaptchaVerifier` à intégrer à l'écran ; TOTP, non.
- Ce qu'on perd : **aucun code de secours**. Firebase n'en génère pas. Un
  admin qui perd son téléphone est bloqué jusqu'à ce qu'un superAdmin lui
  retire son facteur par l'Admin SDK (voir « Perte du téléphone »).

## Parcours cible (code dans `lib/features/admin`)

1. **Connexion** (e-mail ou Google) par `authRepositoryProvider`, comme
   avant. Firebase accepte le premier facteur puis, **si le compte porte un
   facteur enrôlé**, interrompt la connexion : `FirebaseAuthMultiFactorException`
   (`multi-factor-auth-required`), **sans ouvrir de session**. La datasource la
   fait ressortir en `SecondFacteurRequisFailure`, qui porte le défi
   (`DefiSecondFacteur`), et le dépôt la rend en `Left`.
2. **Compte admin sans facteur** (la connexion a abouti d'un coup) → écran
   d'enrôlement `AdminEnrolementTotpScreen` : QR code (`otpauth://totp/…`,
   émetteur « DiaspoNiger Admin »), clé en clair pour une saisie manuelle,
   champ du premier code. `terminerEnrolementTotp` le vérifie et enrôle le
   facteur. Sans ce passage, **pas de tableau de bord**.
3. **Compte avec facteur** → écran de défi `AdminDefiSecondFacteurScreen` :
   le code de l'application. `resoudreSecondFacteur` achève la connexion
   (session Firebase, pont Supabase, lecture du profil), puis le panneau
   applique le même refus qu'avant si le compte n'est pas admin
   (déconnexion + message).
4. **Garde de `/dashboard`** (`GardeTableauDeBord`) : rôle lu dans le jeton
   **et** au moins un facteur enrôlé sur le compte. Un admin connecté sans
   facteur qui tape l'adresse voit l'enrôlement, pas le tableau de bord.
5. **Non-admin** : inchangé — refus et déconnexion, que le compte ait un
   facteur ou non (`admin_login_signout_test.dart`).

Vérifié hors appareil : `flutter test test/features/admin` (faux
`AuthRepository`, sans Firebase). Le parcours réel, avec un vrai téléphone et
une vraie application d'authentification, est dans
`TESTS_APPAREIL_A_FAIRE.md` (domaine 13) — il ne peut se faire qu'après
l'activation de TOTP ci-dessus.

## Ce qui n'est pas couvert, exprès

- **L'app mobile ne résout pas le défi.** Un compte admin qui a enrôlé TOTP
  reçoit, dans l'app grand public, « Ce compte exige un second facteur :
  connectez-vous depuis le panneau d'administration » et n'y entre plus.
  C'est voulu tant que les comptes admin sont des comptes de panneau ; si un
  admin doit aussi utiliser l'app avec le même compte, il faudra y brancher
  le même écran de défi (le dépôt le sait déjà faire).
- **Le facteur SMS** : si un compte n'a qu'un facteur SMS (enrôlé ailleurs),
  le panneau le refuse avec un message — il ne gère que TOTP.
- **Retirer son propre facteur** depuis le panneau : pas d'écran. Passer par
  l'Admin SDK (ci-dessous) ; un écran viendra si le besoin se présente.
- **Plusieurs facteurs** : le panneau enrôle un TOTP et un seul (Firebase en
  accepte jusqu'à cinq par compte, tous types confondus).

## Perte du téléphone : retirer le facteur d'un admin

Firebase ne génère pas de codes de secours. Le seul chemin est l'Admin SDK,
par un superAdmin, depuis `functions/` avec la clé de service :

```js
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./diaspo-niger-firebase-adminsdk-fbsvc-a3182736fb.json')) });
const u = await admin.auth().getUserByEmail('<e-mail de l’admin>');
await admin.auth().updateUser(u.uid, { multiFactor: { enrolledFactors: null } });
await admin.auth().revokeRefreshTokens(u.uid);
```

Après quoi l'admin se reconnecte et retombe sur l'enrôlement, comme la
première fois. À outiller (`tools/retirer_second_facteur.mjs`, lecture seule
sans `--confirmer`, sur le modèle de `tools/amorcer_super_admin.mjs`) le jour
où ça sert ; d'ici là, cette recette suffit.

## Liste de ce que Salim fait lui-même, dans l'ordre

1. Relever combien de comptes ont un facteur SMS (script « Combien de
   comptes… » ci-dessus). Zéro attendu.
2. Activer TOTP : console si la bascule existe, sinon le `PATCH`. Garder
   `PHONE_SMS` si le point 1 n'a pas rendu zéro.
3. Relire la configuration (`GET`) : `providerConfigs[0].state == ENABLED`.
4. Déployer le panneau (quand il aura une cible d'hébergement — § 10 point 7
   de l'audit, toujours ouvert) et dérouler l'entrée du domaine 13 de
   `TESTS_APPAREIL_A_FAIRE.md` avec le compte de test
   (`test.diaspo@example.com`, superAdmin après amorçage) et un téléphone
   portant une application d'authentification.
5. Enrôler **son** compte en premier, et garder la recette « Perte du
   téléphone » sous la main avant d'imposer le facteur aux autres admins.
