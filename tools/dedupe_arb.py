#!/usr/bin/env python3
"""Supprime les cles JSON declarees plusieurs fois dans un fichier ARB.

Un ARB avec une cle dupliquee est un JSON ambigu : le parseur applique
last-wins, donc la valeur reellement utilisee depend de l'ordre d'ecriture et
non d'une decision. Les locales peuvent alors diverger en silence, et une
edition faite sur la « mauvaise » occurrence n'a aucun effet visible.

Regle appliquee, pour chaque cle dupliquee :

  - on garde la POSITION de la premiere occurrence, parce que c'est presque
    toujours celle qui est alignee sur l'ordre du template (mesure sur
    app_en.arb : le voisinage de app_fr.arb designe 268 fois la premiere
    occurrence contre 1 fois la derniere) ;
  - on y ecrit la VALEUR de la derniere occurrence, parce que c'est celle que
    le parseur retient deja aujourd'hui.

Le nettoyage est donc un no-op semantique : aucun texte affiche ne change,
meme pour les cles dont les variantes divergent.

Garde-fou : le script refuse d'ecrire si le JSON obtenu apres nettoyage n'est
pas rigoureusement identique au JSON obtenu avant.

Usage :
    python tools/dedupe_arb.py lib/l10n/app_en.arb lib/l10n/app_fr.arb
    python tools/dedupe_arb.py --check lib/l10n/*.arb   # audit seul, sans ecriture
    python tools/dedupe_arb.py --report lib/l10n/app_en.arb  # detaille les divergences
"""

import json
import re
import sys

# Une entree de premier niveau d'un ARB commence par exactement deux espaces
# puis un guillemet. Les valeurs sont des chaines JSON (sauts de ligne
# echappes), donc aucune valeur ne peut ouvrir une fausse entree.
TOP_LEVEL = re.compile(r'^  "((?:[^"\\]|\\.)*)"\s*:')

DECODER = json.JSONDecoder()


def _skip_space(text, index):
    while index < len(text) and text[index] in " \t\r\n":
        index += 1
    return index


class Entry:
    """Une entree de premier niveau : ses lignes propres, puis les lignes qui
    la suivent jusqu'a l'entree suivante (lignes vides de respiration,
    accolade fermante du fichier pour la derniere)."""

    def __init__(self, key, lines):
        text = "\n".join(lines)
        after_colon = text.index(":", len(key)) + 1
        self.value, end = DECODER.raw_decode(text, _skip_space(text, after_colon))
        # La virgule separatrice appartient a l'entree, ou qu'elle se trouve :
        # app_en.arb en compte quelques-unes isolees sur leur propre ligne,
        # sequelles d'editions passees. Sans cela une entree deplacee laisse
        # derriere elle une virgule orpheline.
        after = _skip_space(text, end)
        if after < len(text) and text[after] == ",":
            end = after + 1
        used = text.count("\n", 0, end) + 1
        self.key = key
        self.lines = lines[:used]
        self.trailing = lines[used:]
        # La virgule est retiree ici et reattribuee au remontage, selon la
        # position finale de l'entree.
        self.lines[-1] = self.lines[-1].rstrip().rstrip(",")
        while len(self.lines) > 1 and not self.lines[-1].strip():
            self.lines.pop()

    def emit(self, comma):
        lines = list(self.lines)
        if comma:
            lines[-1] += ","
        return lines


def parse(text):
    """Renvoie (entete, entrees, pied). Le pied porte l'accolade fermante."""
    lines = text.split("\n")
    starts = [i for i, line in enumerate(lines) if TOP_LEVEL.match(line)]
    if not starts:
        return lines, [], []

    entries = []
    for n, start in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(lines)
        key = TOP_LEVEL.match(lines[start]).group(1)
        entries.append(Entry(key, lines[start:end]))

    # Le pied est detache de la derniere entree : celle-ci peut etre supprimee
    # ou deplacee, l'accolade fermante ne bouge pas.
    footer = entries[-1].trailing
    entries[-1].trailing = []
    return lines[: starts[0]], entries, footer


def dedupe(text):
    """Renvoie (texte_nettoye, statistiques). Leve AssertionError si le JSON
    resultant differe du JSON d'origine."""
    header, entries, footer = parse(text)

    slot = {}  # cle -> indice de la premiere occurrence (position conservee)
    winner = {}  # cle -> indice de la derniere occurrence (valeur conservee)
    for n, entry in enumerate(entries):
        slot.setdefault(entry.key, n)
        winner[entry.key] = n

    kept = [n for n in range(len(entries)) if slot[entries[n].key] == n]

    out = list(header)
    for rank, n in enumerate(kept):
        source = entries[winner[entries[n].key]]
        out.extend(source.emit(comma=rank < len(kept) - 1))
        out.extend(entries[n].trailing)
    out.extend(footer)
    result = "\n".join(out)

    before = json.loads(text)
    after = json.loads(result)
    assert before == after, "le JSON a change : dedoublonnage refuse"

    moved = sum(1 for n in kept if winner[entries[n].key] != n)
    stats = {
        "keys": len(slot),
        "entries": len(entries),
        "removed": len(entries) - len(kept),
        "rewritten": moved,
        "lines_before": len(text.split("\n")),
        "lines_after": len(out),
    }
    return result, stats


def divergences(text):
    """Cles dupliquees dont les variantes n'ont pas toutes la meme valeur, avec
    la valeur retenue (la derniere). Matiere a relecture editoriale.

    La comparaison porte sur la valeur analysee, pas sur le texte brut : une
    difference de mise en forme du JSON n'est pas une divergence."""
    _, entries, _ = parse(text)
    seen = {}
    for entry in entries:
        seen.setdefault(entry.key, []).append(
            json.dumps(entry.value, ensure_ascii=False, sort_keys=True)
        )
    return {k: v for k, v in seen.items() if len(v) > 1 and len(set(v)) > 1}


def read(path):
    with open(path, encoding="utf-8", newline="") as handle:
        return handle.read()


def main(argv):
    check_only = "--check" in argv
    report = "--report" in argv
    paths = [a for a in argv if not a.startswith("--")]
    if not paths:
        print(__doc__)
        return 2

    failed = False
    for path in paths:
        text = read(path)
        if "\r\n" in text:
            print("%s : fins de ligne CRLF, non supporte" % path)
            failed = True
            continue
        try:
            result, stats = dedupe(text)
        except AssertionError as exc:
            print("%s : %s" % (path, exc))
            failed = True
            continue

        print(
            "%s : %d cles distinctes, %d entrees ecrites, %d en trop, "
            "%d valeurs remontees (%d lignes -> %d)"
            % (
                path,
                stats["keys"],
                stats["entries"],
                stats["removed"],
                stats["rewritten"],
                stats["lines_before"],
                stats["lines_after"],
            )
        )

        if report:
            diverging = divergences(text)
            print("  %d cles dupliquees a valeurs divergentes :" % len(diverging))
            for key, variants in sorted(diverging.items()):
                print("    %s -> retenu : %s" % (key, variants[-1]))
                for variant in variants[:-1]:
                    print("        abandonne : %s" % variant)

        if check_only:
            if stats["removed"]:
                failed = True
            continue

        if result != text:
            with open(path, "w", encoding="utf-8", newline="") as handle:
                handle.write(result)

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
