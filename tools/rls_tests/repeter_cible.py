"""Injecte un fichier CIBLE dans son banc, pour une répétition en BEGIN … ROLLBACK.

    python tools/rls_tests/repeter_cible.py <banc.sql> <cible.sql> <sortie.sql>
    supabase db query --linked -f <sortie.sql>

Le banc porte une ligne seule `-- @@CIBLE@@` ; elle est remplacée par le
contenu de la cible.

POURQUOI UN OUTIL ET PAS UN COPIER-COLLER. Une cible décrit une fermeture
qu'on n'applique PAS encore. Sa répétition tourne sur la production, à
l'intérieur d'une transaction que le banc annule à la fin. Si le texte injecté
contient un `COMMIT` (ou un `ROLLBACK`, un `END`), la transaction se termine au
milieu : le `COMMIT` VALIDE la fermeture en production, et le `ROLLBACK` final
n'annule plus rien — pire, avec un `ROLLBACK` injecté, tout ce qui suit dans le
banc (ses lignes d'essai comprises) s'exécute hors transaction et reste en
base. Aucune sauvegarde Supabase n'existe : ce serait irréversible.

L'outil refuse donc d'injecter un texte qui contient, hors commentaire, une
instruction de contrôle de transaction.
"""
import io
import re
import sys

INTERDIT = re.compile(
    r"^\s*(BEGIN|COMMIT|END|ROLLBACK|START\s+TRANSACTION|SAVEPOINT|RELEASE)\b",
    re.IGNORECASE,
)


def sans_commentaires(sql: str) -> list[str]:
    """Lignes de code, commentaires `--` et blocs `/* */` retirés."""
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    return [ligne.split("--", 1)[0] for ligne in sql.split("\n")]


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    banc_p, cible_p, sortie_p = sys.argv[1:]
    banc = io.open(banc_p, encoding="utf-8").read().replace("\r\n", "\n")
    cible = io.open(cible_p, encoding="utf-8").read().replace("\r\n", "\n")

    fautes = [
        (n, ligne.strip())
        for n, ligne in enumerate(sans_commentaires(cible), 1)
        if INTERDIT.match(ligne)
    ]
    if fautes:
        print("REFUS : la cible contient un contrôle de transaction.")
        for n, ligne in fautes:
            print(f"  {cible_p}:{n}  {ligne}")
        print("Injectée dans la répétition, elle validerait en production.")
        return 1

    lignes = banc.split("\n")
    marques = [i for i, l in enumerate(lignes) if l.strip() == "-- @@CIBLE@@"]
    if len(marques) != 1:
        print(f"REFUS : {len(marques)} marque(s) `-- @@CIBLE@@` dans le banc, il en faut une.")
        return 1

    # Le banc lui-même doit ouvrir ET annuler, sinon la répétition n'en est pas une.
    code_banc = [l.strip().upper() for l in sans_commentaires(banc) if l.strip()]
    if "BEGIN;" not in code_banc or "ROLLBACK;" not in code_banc:
        print("REFUS : le banc doit contenir `BEGIN;` et `ROLLBACK;`.")
        return 1
    if code_banc[-1] != "ROLLBACK;":
        print("REFUS : `ROLLBACK;` doit être la dernière instruction du banc.")
        return 1

    lignes[marques[0]] = cible
    io.open(sortie_p, "w", encoding="utf-8", newline="\n").write("\n".join(lignes))
    print(f"répétition écrite : {sortie_p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
