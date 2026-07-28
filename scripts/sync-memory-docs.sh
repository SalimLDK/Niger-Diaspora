#!/usr/bin/env bash
#
# sync-memory-docs.sh — met à jour docs/memory/ à partir du store de mémoire
# par-projet de Claude Code, en EXCLUANT les fichiers sécurité-sensibles qui ne
# doivent jamais entrer dans l'historique git.
#
# Le store vivant (que Claude lit/écrit) reste la source de vérité ; docs/memory/
# n'en est qu'un instantané versionné, moins la liste d'exclusion ci-dessous.
#
# Usage :
#   ./scripts/sync-memory-docs.sh          # synchronise, puis affiche le diff à relire
#   CLAUDE_MEMORY_DIR=/autre/chemin ./scripts/sync-memory-docs.sh
#
# Le script NE committe PAS : relisez `git status docs/memory` avant de commiter.

set -euo pipefail

# ── Fichiers gardés HORS dépôt (identifiant coturn divulgué, IP VPS, inventaire
#    des faiblesses de secrets de prod). Source unique de vérité. ──────────────
EXCLUDE=(
  project_coturn_vps.md
  project_firebase_functions_deploy_blocked.md
)

# ── Chemins ───────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/docs/memory"

# Store de mémoire de Claude pour CE projet (slug = chemin absolu encodé).
# Surchargeable via CLAUDE_MEMORY_DIR si le chemin diffère sur une autre machine.
DEFAULT_SRC="$HOME/.claude/projects/C--Users-danko-StudioProjects-projet-perso-diaspo-niger/memory"
MEM_SRC="${CLAUDE_MEMORY_DIR:-$DEFAULT_SRC}"

if [ ! -d "$MEM_SRC" ]; then
  echo "✗ Store de mémoire introuvable : $MEM_SRC" >&2
  echo "  Définissez CLAUDE_MEMORY_DIR vers le dossier memory/ de ce projet." >&2
  exit 1
fi

mkdir -p "$DEST"
shopt -s nullglob

is_excluded() {
  local name="$1" e
  for e in "${EXCLUDE[@]}"; do [ "$name" = "$e" ] && return 0; done
  return 1
}

# ── 1) Purger de docs/memory ce qui a disparu de la source (miroir) ───────────
for f in "$DEST"/*.md; do
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue
  if [ ! -f "$MEM_SRC/$base" ] || is_excluded "$base"; then rm -f "$f"; fi
done

# ── 2) Copier chaque mémoire sauf l'index et les exclues ──────────────────────
copied=0
for f in "$MEM_SRC"/*.md; do
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue
  is_excluded "$base" && continue
  cp "$f" "$DEST/$base"
  copied=$((copied + 1))
done

# ── 3) Reconstruire l'index : retirer les lignes des fichiers exclus (ce qui
#       supprime aussi l'IP VPS du lien coturn), puis ajouter la note ──────────
grep_pat="$(printf '%s\n' "${EXCLUDE[@]}" | sed 's/\./\\./g' | paste -sd'|' -)"
{
  grep -vE "\]\((${grep_pat})\)" "$MEM_SRC/MEMORY.md"
  printf '\n> Note : deux mémoires sécurité-sensibles (`project_coturn_vps`, `project_firebase_functions_deploy_blocked`) sont volontairement **hors dépôt** — instantané généré par scripts/sync-memory-docs.sh.\n'
} > "$DEST/MEMORY.md"

# ── 4) Garde-fou : vérifier qu'aucun motif sensible connu n'a fui ─────────────
if grep -rInE "DiaspoNiger2026Secure|72\.62\.212\.223|whsec_your_webhook|sk_live_" "$DEST" >/dev/null 2>&1; then
  echo "✗ Contenu sensible détecté dans $DEST — commit annulé, inspectez :" >&2
  grep -rInE "DiaspoNiger2026Secure|72\.62\.212\.223|whsec_your_webhook|sk_live_" "$DEST" >&2
  exit 2
fi

echo "✓ $copied mémoire(s) synchronisée(s) → docs/memory/ (exclues : ${EXCLUDE[*]})"
echo
git -C "$REPO_ROOT" status --short docs/memory || true
echo
echo "Relisez, puis : git add docs/memory && git commit -m 'docs(memory): sync'"
