#!/usr/bin/env bash
# Construit le panneau admin (lib/features/admin/main.dart) pour le web, dans
# build/web_admin — le dossier que sert la cible Hosting `admin` de
# firebase.json. Ne déploie rien : voir docs/deploiement/HEBERGEMENT_ADMIN.md.
#
# Usage, depuis la racine du dépôt (ou n'importe où) :
#   bash tools/build_admin_web.sh
#
# Variables lues, dans l'ordre : l'environnement, puis le .env racine.
#   SUPABASE_URL, SUPABASE_ANON_KEY   obligatoires — passées en --dart-define,
#                                     parce que `assets/.env` n'est PAS publié
#                                     (firebase.json ignore `**/.*`) : sans
#                                     elles le panneau lève StateError au
#                                     démarrage (lib/features/admin/main.dart).
#   ADMIN_RECAPTCHA_SITE_KEY          facultative — clé de site reCAPTCHA v3
#                                     d'App Check ; à défaut RECAPTCHA_SITE_KEY
#                                     du .env ; à défaut, le repli compilé
#                                     (lib/features/admin/cle_site_recaptcha.dart).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Lit une clé du .env racine (ignoré par git). `tr -d '\r'` : le fichier peut
# être en CRLF sur ce poste, et un retour chariot collé à la valeur casserait
# l'URL en silence.
lire_env() {
  [[ -f .env ]] || return 0
  grep -E "^${1}=" .env | head -n 1 | cut -d= -f2- | tr -d '\r"' || true
}

SUPABASE_URL="${SUPABASE_URL:-$(lire_env SUPABASE_URL)}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(lire_env SUPABASE_ANON_KEY)}"
ADMIN_RECAPTCHA_SITE_KEY="${ADMIN_RECAPTCHA_SITE_KEY:-$(lire_env RECAPTCHA_SITE_KEY)}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "SUPABASE_URL et SUPABASE_ANON_KEY sont requis (environnement ou .env racine)." >&2
  exit 1
fi
case "$SUPABASE_URL" in
  https://*) ;;
  *) echo "SUPABASE_URL doit commencer par https:// (AppConfig.isSupabaseConfigured)." >&2; exit 1 ;;
esac

defines=(
  --dart-define=PRODUCTION=true
  --dart-define="SUPABASE_URL=${SUPABASE_URL}"
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
)
if [[ -n "$ADMIN_RECAPTCHA_SITE_KEY" ]]; then
  defines+=(--dart-define="ADMIN_RECAPTCHA_SITE_KEY=${ADMIN_RECAPTCHA_SITE_KEY}")
  echo "reCAPTCHA : clé passée en --dart-define."
else
  echo "reCAPTCHA : aucune clé fournie, repli compilé (cle_site_recaptcha.dart)."
fi

# CLAUDE.md : cargokit ne sert qu'aux builds Android/iOS, mais exporter le
# PATH de cargo ne coûte rien et évite une surprise si l'outillage change.
export PATH="$HOME/.cargo/bin:$PATH"

# --no-web-resources-cdn : CanvasKit servi depuis build/web_admin/canvaskit/
#   au lieu de gstatic.com — une origine de script en moins dans la CSP.
# --csp : dart2js n'émet plus de code généré à l'exécution (`new Function`),
#   donc pas de 'unsafe-eval' dans la CSP ; 'wasm-unsafe-eval' suffit pour
#   CanvasKit.
flutter build web \
  --release \
  -t lib/features/admin/main.dart \
  -o build/web_admin \
  --no-web-resources-cdn \
  --csp \
  "${defines[@]}"

# Ceinture et bretelles : le .env (asset pubspec, donc copié dans le build)
# est déjà exclu du déploiement par `**/.*` ; on le retire aussi du dossier,
# pour qu'aucun autre outil de publication ne l'emporte. Le panneau n'en lit
# rien : tout passe par les --dart-define ci-dessus.
rm -f build/web_admin/assets/.env

# Contrôle : c'est bien l'entrée du panneau qui a été compilée, pas lib/main.dart.
if ! grep -q "DiaspoNiger Admin" build/web_admin/main.dart.js; then
  echo "build/web_admin/main.dart.js ne contient pas le titre du panneau : mauvaise entrée ?" >&2
  exit 1
fi

echo
echo "Build du panneau : build/web_admin ($(du -sh build/web_admin | cut -f1))."
echo "Déploiement (étape de Salim) : firebase deploy --only hosting:admin --project diaspo-niger"
