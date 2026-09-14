"""Retire d'Inter les glyphes monochromes qui masquent des emojis couleur.

Pourquoi : Inter dessine sa propre version de quelques caractères qui ont
AUSSI une forme emoji — dont le cœur U+2764. Flutter prend le glyphe de la
police du style dès qu'elle en a un, sans tenir compte du sélecteur de
variante U+FE0F : « ❤️ » s'affichait donc en cœur NOIR partout où le texte
est en Inter (réactions, bulles, composeur, aperçus), alors que la police
système du téléphone (Roboto, vérifié sur SM A515F et Pixel) n'a pas ce
glyphe et laisse la main à la police emoji.

On ne retire que l'entrée de la table `cmap` : le caractère n'est plus
« couvert » par Inter, le moteur passe à la police de repli (emoji couleur).
Le dessin reste dans le fichier, inaccessible.

Liste volontairement courte : ⚠ et ↗ restent dans Inter, l'interface les
emploie comme symboles de texte (salons audio) et ils doivent garder la
couleur du style.

Usage :
    python tools/polices_emoji_couleur.py          # applique
    python tools/polices_emoji_couleur.py --check  # échoue si un glyphe est revenu

Vérifié aussi par test/core/polices_emoji_couleur_test.dart.
"""

import glob
import sys

from fontTools.ttLib import TTFont

# Point de code -> ce qu'on y gagne.
CIBLES = {
    0x2764: "cœur rouge ❤️",
    0x2665: "cœur de carte ♥️",
    0x2600: "soleil ☀️",
}

POLICES = "assets/google_fonts/Inter-*.ttf"


def glyphes_presents(police: TTFont) -> set[int]:
    presents = set()
    for table in police["cmap"].tables:
        presents.update(cp for cp in CIBLES if cp in table.cmap)
    return presents


def main() -> int:
    verifier = "--check" in sys.argv
    fichiers = sorted(glob.glob(POLICES))
    if not fichiers:
        print(f"aucune police trouvée ({POLICES})")
        return 1

    fautifs = 0
    for chemin in fichiers:
        police = TTFont(chemin)
        presents = glyphes_presents(police)
        if not presents:
            print(f"ok      {chemin}")
            continue
        noms = ", ".join(CIBLES[cp] for cp in sorted(presents))
        if verifier:
            print(f"FAUTIF  {chemin} : {noms}")
            fautifs += 1
            continue
        for table in police["cmap"].tables:
            for cp in CIBLES:
                table.cmap.pop(cp, None)
        police.save(chemin)
        print(f"retiré  {chemin} : {noms}")

    return 1 if fautifs else 0


if __name__ == "__main__":
    sys.exit(main())
