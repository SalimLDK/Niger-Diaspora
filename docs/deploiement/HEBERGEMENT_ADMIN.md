# Hébergement du panneau admin — site `diaspo-niger-admin`

Le panneau admin (`lib/features/admin/main.dart`) est une seconde application
Flutter, conçue pour le web. Jusqu'au 2026-10-14, rien dans le dépôt ne la
construisait ni ne l'hébergeait (audit du 2026-10-14, § 1 et § 10 point 7).
Ce guide décrit la cible Hosting dédiée posée ce jour-là, comment construire,
ce que Salim doit faire dans les consoles, et comment vérifier.

**Rien n'a été déployé.** Le déploiement et les consoles sont les étapes de
Salim (§ 3, § 4).

## État trouvé le 2026-10-14

`firebase hosting:sites:list --project diaspo-niger` rend **trois** sites, pas
deux : `diaspo-niger`, `diasponiger` (marketing) et **`diaspo-niger-admin`**,
inconnu du dépôt. Il sert un build du panneau (`main.dart.js` de 3,4 Mo,
titre « DiaspoNiger Admin », `Last-Modified: 25 Feb 2026`), donc antérieur à
tout ce que l'audit a corrigé : sans `Supabase.initialize`, sans délégués de
localisation — un panneau qui ne peut rien faire. Ses en-têtes : aucun en-tête
de sécurité, `Cache-Control: max-age=3600` sur `index.html` (une heure de
retard garantie après chaque déploiement). `assets/.env` n'y est pas publié
(le chemin rend `index.html` par la réécriture) : le `.env` embarqué n'a
jamais été exposé par ce site.

Le site existe : **pas de création à faire dans la console.** La cible
`admin` de `.firebaserc` pointe dessus.

## 1. Ce que le dépôt porte

| Fichier | Rôle |
|---|---|
| `firebase.json` | troisième entrée `hosting`, `"target": "admin"`, `"public": "build/web_admin"`, réécriture SPA `** → /index.html`, en-têtes (§ 5), `ignore` des dotfiles, des `.symbols` (8 Mo de symboles de débogage CanvasKit) et des moteurs `skwasm`/`wimp`/`experimental_webparagraph` que le rendu `canvaskit` ne charge jamais |
| `.firebaserc` | `targets.diaspo-niger.hosting.admin = ["diaspo-niger-admin"]` (ce que `firebase target:apply hosting admin diaspo-niger-admin` aurait écrit) |
| `.gitignore` | `build/web_admin` est déjà couvert par `/build/` (`.gitignore:48`), rien à ajouter |
| `lib/features/admin/cle_site_recaptcha.dart` | clé de site reCAPTCHA v3 par `--dart-define=ADMIN_RECAPTCHA_SITE_KEY`, repli = la clé du projet |
| `lib/core/constants/app_config.dart` | `_dartDefines`, table constante des `--dart-define` lus par `_read` (§ 6, le bug trouvé en construisant) |
| `tools/build_admin_web.sh` | le build complet (§ 2) |
| `tools/injecter_csp_meta.py` | test local de la CSP, l'émulateur n'appliquant pas les en-têtes (§ 7) |

Le `/admin` du site marketing : il n'y a **pas** de règle `/admin` dans
`firebase.json` — c'est la règle attrape-tout `**` → `/index.html` des deux
sites marketing qui rend la page d'accueil pour `/admin` comme pour tout
chemin inconnu. Elle est gardée telle quelle, sans redirection vers le panneau :
l'adresse du back-office n'a rien à faire sur le domaine public, et `/admin/*`
est aussi une famille de routes de l'app mobile (`/admin/embassies`,
`/admin/support`) que les App Links de `diasponiger.web.app` intercepteraient.

## 2. Construire

```bash
bash tools/build_admin_web.sh
```

Le script lit `SUPABASE_URL`, `SUPABASE_ANON_KEY` (obligatoires) et
`RECAPTCHA_SITE_KEY` (facultative) dans l'environnement, puis dans le `.env`
racine, et lance :

```bash
flutter build web --release \
  -t lib/features/admin/main.dart \
  -o build/web_admin \
  --no-web-resources-cdn \
  --csp \
  --dart-define=PRODUCTION=true \
  --dart-define=SUPABASE_URL=… \
  --dart-define=SUPABASE_ANON_KEY=… \
  --dart-define=ADMIN_RECAPTCHA_SITE_KEY=…
```

Pourquoi chaque drapeau :

- **`SUPABASE_URL` / `SUPABASE_ANON_KEY` en `--dart-define`** : le `.env`
  racine est un asset pubspec, donc copié dans `build/web_admin/assets/.env` —
  mais `firebase.json` ignore `**/.*` et le script l'efface après le build. Le
  panneau ne lit donc rien du `.env` en ligne ; `AppConfig._read` prend le
  `--dart-define` en premier. Sans eux, `main.dart` lève `StateError`
  « SUPABASE_URL / SUPABASE_ANON_KEY manquants » avant `runApp`. La clé anon
  est publique de toute façon (elle est dans le bundle comme elle serait dans
  l'APK) ; ce qui reste hors ligne, ce sont les **autres** clés du `.env`
  (Maps, identifiants OAuth…) dont le panneau n'a pas besoin.
- **`--no-web-resources-cdn`** : CanvasKit servi depuis
  `build/web_admin/canvaskit/` au lieu de `www.gstatic.com/flutter-canvaskit/`
  — une origine de script en moins dans la CSP, et pas de version d'engine
  qui dérive entre le bundle et le CDN.
- **`--csp`** : dart2js n'émet plus de code généré à l'exécution
  (`new Function`), donc pas de `'unsafe-eval'` dans la CSP. CanvasKit reste
  du WebAssembly : `'wasm-unsafe-eval'` suffit.
- **`PRODUCTION=true`** : même valeur que les builds release de l'app.
- **`ADMIN_RECAPTCHA_SITE_KEY`** : facultatif, le repli compilé est la clé du
  projet (`6Ldy7Tws…`, la même que `lib/main.dart`). Une clé de site reCAPTCHA
  n'est pas un secret — elle est dans la page — ; le `--dart-define` sert à en
  changer (clé dédiée au panneau, rotation) sans toucher au code.

Ce que Flutter 3.44 produit, à savoir : **plus de service worker de cache**
(`flutter_service_worker.js` est un talon qui se désinscrit lui-même) — un
déploiement est visible au rechargement suivant, pourvu que `index.html` et
`main.dart.js` ne soient pas mis en cache une heure, d'où le
`Cache-Control: public, max-age=0, must-revalidate` sur `**` (ETag → 304,
rien de lourd n'est retéléchargé s'il n'a pas changé).

Durée mesurée le 2026-10-14 : 162 s de compilation au premier build, 49 Mo
dans `build/web_admin` (dont ~29 Mo ignorés au déploiement par les motifs
`ignore` ci-dessus).

## 3. Déployer — étape de Salim

```bash
firebase deploy --only hosting:admin --project diaspo-niger
```

⚠ **Effet de bord sur le déploiement du site marketing.** `firebase deploy
--only hosting` sans cible déploie désormais **les trois** sites, et le CLI
exige que `build/web_admin` existe — sinon il s'arrête en phase de préparation,
avant tout envoi, sur « Directory 'build/web_admin' for Hosting does not
exist ». Pour le marketing seul :

```bash
firebase deploy --only hosting:diaspo-niger,hosting:diasponiger --project diaspo-niger
```

Un canal d'aperçu, pour voir le panneau en ligne sans toucher à la production
(non lancé le 2026-10-14, exprès) :

```bash
firebase hosting:channel:deploy aperçu --only admin --expires 1d --project diaspo-niger
```

Retour arrière : console Firebase → Hosting → site `diaspo-niger-admin` →
historique des versions → « Restaurer ».

## 4. Origines à autoriser dans les consoles — étape de Salim

Le domaine servi est `https://diaspo-niger-admin.web.app`. Trois consoles
doivent le connaître ; aucune commande du dépôt ne le fait.

| Console | Où | Quoi | Sinon |
|---|---|---|---|
| **reCAPTCHA** (`https://www.google.com/recaptcha/admin`), clé `6Ldy7Tws…` | Paramètres → Domaines | ajouter `diaspo-niger-admin.web.app` | App Check ne reçoit jamais de jeton : silencieux tant que `enforceAppCheck` n'est pas posé sur les callables (audit § 10.7), bloquant dès qu'il le sera |
| **Google Cloud** → Identifiants → client OAuth web `539228418594-dg3fs7g5pnshbeib3jj4ukifv8pid622` | Origines JavaScript autorisées | ajouter `https://diaspo-niger-admin.web.app` | « Se connecter avec Google » du panneau échoue (« The given origin is not allowed for the given client ID ») ; e-mail + mot de passe n'en dépend pas |
| **Firebase** → Authentication → Settings → Domaines autorisés | liste | vérifier que `diaspo-niger-admin.web.app` y est (les sites Hosting du projet y sont souvent ajoutés d'office) | la fenêtre d'authentification Firebase (`diaspo-niger.firebaseapp.com/__/auth/…`) refuse l'origine |

**Supabase : rien à autoriser aujourd'hui.** PostgREST répond à toute
origine, et chaque Edge Function appelée par le panneau pose
`Access-Control-Allow-Origin: *` (`auth-firebase-exchange`, `app-config`…).
Les « Redirect URLs » de Supabase Auth ne s'appliquent pas : le panneau
s'authentifie par Firebase, puis par le pont `auth-firebase-exchange` ; il
n'ouvre jamais un OAuth Supabase. Si un jour les Edge Functions restreignent
l'origine, ajouter `https://diaspo-niger-admin.web.app` à chacune.

**Cloud Functions** (`setAdminRole`, `setUserBanned`) : les callables `onCall`
acceptent toute origine, rien à faire.

**App Check** : la console Firebase (App Check → application web) ne liste
pas de domaines ; c'est la clé reCAPTCHA qui porte la liste (première ligne du
tableau).

## 5. Les en-têtes, et chaque origine de la CSP

Posés sur `**` (donc aussi sur `/dashboard`, servi par réécriture — une règle
`**/*.@(html)` ne l'attraperait pas, le chemin ne finit pas en `.html`) :

| En-tête | Valeur | Pourquoi |
|---|---|---|
| `Content-Security-Policy` | ci-dessous | la seule défense contre un script injecté ; le panneau manipule des comptes |
| `X-Frame-Options` | `DENY` | pas de clickjacking ; doublé par `frame-ancestors 'none'` dans la CSP (les navigateurs modernes lisent la CSP, les anciens l'en-tête) |
| `X-Content-Type-Options` | `nosniff` | pas de devinette de type MIME sur `main.dart.js` ou un asset |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | les URL du panneau (`/dashboard`, identifiants dans la barre) ne partent pas vers les tiers ; seule l'origine est envoyée en HTTPS→HTTPS |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | HTTPS seulement pendant un an ; sans `preload`, qui est un engagement de registre (`web.app` y est déjà par son TLD) |
| `Permissions-Policy` | `accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()` | le panneau n'utilise aucun capteur ni paiement ; refusés même à un script tiers |
| `Cache-Control` | `public, max-age=0, must-revalidate` | § 2 : un déploiement est visible au rechargement suivant |

La CSP, directive par directive. Chaque origine a un consommateur identifié
dans le code ou dans les plugins web enregistrés au démarrage (tous les
plugins FlutterFire du `pubspec.yaml` s'enregistrent, que le panneau les
appelle ou non — mesuré en console : `firebase_core`, `auth`, `firestore`,
`functions`, `app_check`, `analytics`, `database`, `messaging`,
`performance`, `remote_config`, `storage` s'initialisent tous).

| Directive | Origines | Qui |
|---|---|---|
| `default-src` | `'self'` | tout ce qui n'est pas listé plus bas reste sur le site |
| `base-uri` | `'self'` | `<base href>` de Flutter ne peut pas être détourné |
| `object-src` | `'none'` | ni Flash, ni `<object>` |
| `frame-ancestors` | `'none'` | le panneau ne s'embarque nulle part |
| `form-action` | `'self'` | aucun `<form>` ne poste ailleurs (Flutter n'en émet pas) |
| `script-src` | `'self'` | `flutter_bootstrap.js`, `main.dart.js`, `canvaskit/` (local grâce à `--no-web-resources-cdn`), `flutter_service_worker.js` |
| | `'wasm-unsafe-eval'` | CanvasKit est du WebAssembly ; `--csp` dispense de `'unsafe-eval'` |
| | `https://www.gstatic.com/firebasejs/` | le SDK Firebase JS, `firebase-<service>.js`, importé au démarrage par chaque plugin FlutterFire |
| | 22 × `'sha256-…'` | **les scripts inline de FlutterFire** (§ 5 bis) : `firebase_core_web` ne pose pas de `<script src>`, il injecte par plugin un script inline `window.ff_trigger_<plugin> = async … import("…firebase-<service>.js")`. Onze plugins, deux gabarits (avec ou sans Trusted Types selon le navigateur) : 22 hachages, régénérés par `tools/csp_hachages_firebasejs.py` |
| | `https://accounts.google.com/gsi/client` | Google Identity Services, chargé par `google_sign_in_web` **dès le démarrage** (dans le constructeur du plugin), utilisé par le bouton Google de l'écran de connexion |
| | `https://www.google.com/recaptcha/`, `https://www.gstatic.com/recaptcha/` | reCAPTCHA v3 d'App Check : `api.js` puis `releases/…` |
| `style-src` | `'self' 'unsafe-inline'` | le moteur Flutter crée des `<style>` en ligne (`flt-glass-pane`, curseurs, polices) : `'unsafe-inline'` est incontournable pour Flutter web |
| | `https://fonts.googleapis.com` | les trois feuilles Material Icons de `web/index.html` |
| | `https://accounts.google.com/gsi/style` | feuille du bouton GIS |
| `font-src` | `'self' data: https://fonts.gstatic.com` | polices du bundle ; `google_fonts` (Inter, `AdminApp`) et Material Icons téléchargées depuis `fonts.gstatic.com` |
| `img-src` | `'self' data: blob: https:` | avatars et images des utilisateurs, signalements : hébergés sur Supabase Storage, Firebase Storage, Google (`lh3.googleusercontent.com`) ou n'importe quel CDN d'un lien partagé — `https:` est la seule liste qui ne casse pas au premier avatar externe ; une image ne peut pas exécuter de code |
| `connect-src` | `'self'` | `assets/`, `version.json` |
| | `https://zyrfkcjjrhddpfxcgezo.supabase.co` | PostgREST, RPC, Edge Functions (`auth-firebase-exchange`, `app-config`) : tout le panneau |
| | `wss://zyrfkcjjrhddpfxcgezo.supabase.co` | temps réel Supabase ; aucun écran admin ne s'abonne aujourd'hui, listée pour que le premier qui le fasse ne tombe pas sur un refus muet — même hôte, aucune surface en plus |
| | `https://identitytoolkit.googleapis.com`, `https://securetoken.googleapis.com` | Firebase Auth : connexion, rafraîchissement du jeton (dont `getIdTokenResult(true)` de la garde `/dashboard`) |
| | `https://firestore.googleapis.com` | `app_config` (réglages, drapeaux) |
| | `https://us-central1-diaspo-niger.cloudfunctions.net` | callables `setAdminRole`, `setUserBanned` (`FirebaseFunctions.instance`, région par défaut ; les fonctions `europe-west1` du projet ne sont pas appelées par le panneau) |
| | `https://content-firebaseappcheck.googleapis.com` | échange du jeton reCAPTCHA contre un jeton App Check |
| | `https://fonts.gstatic.com` | `google_fonts` télécharge Inter par `fetch`, pas par `@font-face` |
| | `https://accounts.google.com/gsi/` | GIS (statut de session, bouton) — la liste que Google documente pour Identity Services |
| `frame-src` | `https://accounts.google.com/gsi/` | iframes du bouton GIS |
| | `https://www.google.com/recaptcha/`, `https://recaptcha.google.com/recaptcha/` | l'ancre reCAPTCHA |
| `worker-src` | `'self' blob:` | inscription de `flutter_service_worker.js` (le talon) ; `blob:` pour les workers que le moteur peut créer |
| `manifest-src` | `'self'` | `manifest.json` |
| `upgrade-insecure-requests` | — | une URL `http://` oubliée est remontée en HTTPS plutôt que bloquée |

### 5 bis. Les hachages des scripts inline de FlutterFire

Mesuré le 2026-10-14 avec la CSP sans hachages : onze
« Executing inline script violates … script-src », une par plugin FlutterFire
du `pubspec.yaml` (core, auth, firestore, functions, app_check, analytics,
database, messaging, performance, remote_config, storage), et le panneau reste
blanc — `Firebase.initializeApp` attend des modules qui ne se chargent jamais.
Le texte de chaque script inline contient la version du SDK JS
(`supportedFirebaseJsSdkVersion`, 11.9.1 avec `firebase_core_web` 2.24.1) et
diffère selon que le navigateur expose Trusted Types (Chrome, Edge) ou non
(Firefox, Safari) : deux gabarits dans `injectSrcScript()`, donc deux séries de
onze hachages.

`tools/csp_hachages_firebasejs.py` les recalcule depuis le poste (versions du
`pubspec.lock`, gabarits et version du SDK lus dans le cache pub, noms de
service lus dans chaque plugin `*_web`) :

```bash
python tools/csp_hachages_firebasejs.py            # affiche
python tools/csp_hachages_firebasejs.py --ecrire   # pose les 22 dans firebase.json
python tools/csp_hachages_firebasejs.py --verifier # exit 1 si firebase.json est en retard
```

**À relancer après toute montée de version de `firebase_core_web`** (donc de
n'importe quel paquet `firebase_*` / `cloud_*`, qui l'entraîne) et avant de
déployer, sinon le prochain déploiement sert un panneau blanc. Vérifié le
2026-10-14 : les onze hachages « Trusted Types » calculés sont exactement ceux
que Chrome affichait dans ses refus. Un plugin FlutterFire ajouté au pubspec
s'enregistre tout seul : relancer `--ecrire` suffit.

Pourquoi pas `'unsafe-inline'` : il annulerait la CSP pour les scripts, la
directive qui compte. Pourquoi pas un `<script type="module">` à soi dans
`web/index.html` (FlutterFire saute l'injection si `window.firebase_core`
existe déjà) : l'ordre d'exécution entre ce module et le `main()` Dart n'est
pas garanti, et la version du SDK y serait à maintenir à la main — les
hachages, eux, se recalculent.

Ce qui **n'est pas** listé, et pourquoi : Firebase Storage, RTDB, Analytics
(`googletagmanager.com`), Messaging — leurs plugins s'enregistrent mais le
panneau n'en appelle aucun ; les ajouter élargirait la CSP sans consommateur.
`https://apis.google.com/js/api.js` (script, ce fichier seul) et son second
script `https://apis.google.com/_/scs/abc-static/_/js/` (préfixe : le nom porte
une version, `k=gapi.lb.en.<hash>`, qui change ; c'est le chemin statique de
gapi, pas l'origine JSONP entière) et
`https://diaspo-niger.firebaseapp.com/__/auth/` (iframe) servent au
`signInWithPopup` de Firebase Auth, utilisé par « Se connecter avec Google »
depuis le 2026-10-15 (`auth_remote_datasource.dart`). Le 2026-10-18 la
connexion Google échouait en `internal-error` : `frame-src` avait été ouvert,
pas `script-src`, et la console disait « Loading the script
'https://apis.google.com/js/api.js' violates … script-src ».
Si un écran admin se met à en utiliser un, l'erreur est lisible en console
(« Refused to connect to … because it violates … connect-src ») : ajouter
l'origine ici et dans `firebase.json`.

## 6. Le bug trouvé en construisant : `String.fromEnvironment` non constant

Le premier build passait, mais la page restait blanche avec « Uncaught Error »
en console. Décodé dans `main.dart.js` :
`String.fromEnvironment can only be used as a const constructor`.
`AppConfig._read` faisait `String.fromEnvironment(dartDefineKey)` avec une
clé **variable** ; sur la VM (Android) l'appel passe et rend la valeur par
défaut — autrement dit les `--dart-define` de ces clés n'ont jamais fonctionné
sur mobile non plus, c'est le `.env` qui faisait tout — ; sur dart2js il lève,
dès `isSupabaseConfigured`, avant tout écran. Corrigé par une table constante
`_dartDefines` (une entrée `String.fromEnvironment('…')` par clé lue) ;
`test/core/constants/app_config_dart_define_test.dart` garde `lib/` libre de
tout `fromEnvironment` à argument variable et vérifie que chaque clé lue par
`_read` a son entrée.

## 7. Vérifier

### En local, sans déployer

```bash
bash tools/build_admin_web.sh
python tools/injecter_csp_meta.py           # CSP en <meta>, test seulement
firebase emulators:start --only hosting:admin --project diaspo-niger
```

Puis `http://127.0.0.1:5000` dans un navigateur, console ouverte : aucun
« Refused to … » attendu, l'écran de connexion s'affiche. **L'émulateur
n'applique pas les `headers` de `firebase.json`** (constaté le 2026-10-14,
firebase-tools 15.30.1 : aucun en-tête sur `/`, `/dashboard` ni
`/main.dart.js`, et les motifs `ignore` n'y jouent pas non plus, il sert
`assets/.env` et les `.symbols`) — d'où la balise meta, substitut qui couvre
la CSP sauf `frame-ancestors`, et rien des autres en-têtes. `python
tools/injecter_csp_meta.py --retirer` ou rebâtir avant tout déploiement.

### Après déploiement (étape de Salim)

```bash
curl -sI https://diaspo-niger-admin.web.app/ | grep -iE "content-security-policy|x-frame-options|x-content-type-options|referrer-policy|strict-transport-security|permissions-policy|cache-control"
```

Attendu : les sept en-têtes du § 5, `Cache-Control: public, max-age=0,
must-revalidate`. Puis :

```bash
curl -sI https://diaspo-niger-admin.web.app/dashboard | grep -iE "^HTTP|content-security-policy"
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" https://diaspo-niger-admin.web.app/assets/.env
curl -s -o /dev/null -w "%{http_code}\n" https://diaspo-niger-admin.web.app/canvaskit/canvaskit.js.symbols
```

Attendu : `/dashboard` en 200 **avec** la CSP (réécriture SPA + en-tête sur
`**`) ; `assets/.env` en `200 text/html` (c'est `index.html`, jamais un
`.env`) ; le `.symbols` en `text/html` aussi (ignoré, donc réécrit).

Dans le navigateur : console sans « Refused to … », connexion e-mail puis
Google, une action Supabase (ouvrir Utilisateurs), une callable (changer un
rôle) — chacune touche une origine différente de la CSP.

### Vérifié en local le 2026-10-14

Flutter 3.44.2, firebase-tools 15.30.1, navigateur Chromium (Trusted Types
actifs). Rien n'a été déployé ; `hosting:channel:deploy` n'a pas été lancé.

- `bash tools/build_admin_web.sh` : 107 s (162 s au premier build),
  `build/web_admin` 49 Mo, `assets/.env` retiré, marqueur « DiaspoNiger
  Admin » présent dans `main.dart.js`, `flutter_service_worker.js` réduit au
  talon qui se désinscrit.
- Émulateur Hosting sur la cible `admin` seule (`--only hosting:admin`) :
  `/` et `/dashboard` rendent `index.html` (réécriture SPA) ; **aucun en-tête
  de `firebase.json` n'est appliqué**, et les motifs `ignore` non plus — d'où
  `tools/injecter_csp_meta.py`.
- Trois chargements successifs, console lue à chaque fois :
  1. build sans la correction d'`AppConfig` : page blanche, « Uncaught Error »
     = `String.fromEnvironment can only be used as a const constructor` (§ 6).
  2. build corrigé, CSP sans hachages : onze « Executing inline script
     violates … script-src », un par plugin FlutterFire, page blanche (§ 5 bis).
  3. CSP finale (22 hachages, sans `apis.google.com` ni
     `diaspo-niger.firebaseapp.com`) : **aucune violation**, aucune erreur
     hormis le 404 de l'émulateur sur `assets/.env` (en production ce chemin
     rend `index.html`, `dotenv` l'ignore), titre « DiaspoNiger Admin »,
     route `/login`, écran de connexion complet (bouton Google, e-mail, mot de
     passe).
- Ressources externes réellement chargées au démarrage (lues par
  `performance.getEntriesByType('resource')`), toutes dans la CSP :
  `www.gstatic.com/firebasejs/11.9.1/` × 11, `accounts.google.com/gsi/client`,
  `www.google.com/recaptcha/api.js` + iframe `api2/anchor`,
  `www.gstatic.com/recaptcha/releases/`, `fonts.googleapis.com/icon` × 3,
  `fonts.gstatic.com`. CanvasKit depuis `canvaskit/chromium/` en local.
- Non exercé ici (pas de compte de test avec mot de passe connu, et une
  connexion depuis `127.0.0.1` partirait vers le vrai Firebase) : la
  connexion, donc `identitytoolkit`, `securetoken`, Supabase, les callables.
  Ces origines viennent de la documentation des SDK et du code du panneau ;
  les vérifier au premier déploiement, console ouverte (§ « Après
  déploiement »).
