"""Archive le vérifié de TESTS_APPAREIL_A_FAIRE.md dans TESTS_APPAREIL_FAITS.md.

La liste ne doit montrer que ce qui reste à voir. Deux choses en sortent :

- une **entrée** (titre `##` sous un domaine `# N.`) dont toutes les cases
  sont cochées part en entier, notes comprises ;
- dans une entrée encore ouverte, chaque **case cochée** part avec ses lignes
  de suite (notes indentées, sous-listes), sauf si son bloc contient encore
  une case ouverte. Une ligne de renvoi la remplace dans l'entrée.

Rien n'est effacé : l'archive garde la trace de qui a vu quoi, sur quel
build. Elle grandit par sections datées `# Archivage du AAAA-MM-JJ`, les
titres d'origine descendus d'un niveau pour tenir sous le domaine.

Une entrée sans aucune case (méthode, recette, contexte) reste en place.

    python tools/archiver_tests_appareil.py            # archive, puis régénère le sommaire
    python tools/archiver_tests_appareil.py --dry-run  # compte sans rien écrire
"""
import datetime
import re
import subprocess
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
LISTE = RACINE / 'TESTS_APPAREIL_A_FAIRE.md'
ARCHIVE = RACINE / 'TESTS_APPAREIL_FAITS.md'
DEBUT = '<!-- sommaire:debut -->'
FIN = '<!-- sommaire:fin -->'

_CLOTURE = re.compile(r'^\s*(```|~~~)')
_TITRE = re.compile(r'^(#{1,6}) (.+?)\s*$')
_DOMAINE = re.compile(r'^\d+\. ')
_OUVERTE = re.compile(r'^\s*[-*] \[ \]')
_COCHEE = re.compile(r'^\s*[-*] \[[xX]\]')

ENTETE_ARCHIVE = """# Tests sur appareil — déjà vérifiés

Archive de [TESTS_APPAREIL_A_FAIRE.md](TESTS_APPAREIL_A_FAIRE.md) : les
entrées dont toutes les cases sont cochées, et les cases cochées des entrées
encore ouvertes, avec leurs notes (appareil, build, date, ce qui a été vu).
Générée par `tools/archiver_tests_appareil.py` : on n'y écrit pas à la main,
on y cherche (« voir « Titre » » d'une entrée de la liste peut mener ici).

Une régression sur un point archivé se rouvre dans la liste, pas ici.
"""


def _indent(ligne):
    return len(ligne) - len(ligne.lstrip(' '))


def _hors_code(lignes):
    """Vrai pour chaque ligne hors bloc de code et hors sommaire."""
    marque = []
    code = sommaire = False
    for l in lignes:
        s = l.strip()
        if s == DEBUT:
            sommaire = True
        if sommaire:
            marque.append(False)
            if s == FIN:
                sommaire = False
            continue
        if _CLOTURE.match(l):
            code = not code
            marque.append(False)
            continue
        marque.append(not code)
    return marque


def _fin_item(lignes, i, libre):
    """Indice juste après le bloc de l'item qui commence en `i`."""
    base = _indent(lignes[i])
    j = i + 1
    while j < len(lignes):
        l = lignes[j]
        if not l.strip():
            k = j
            while k < len(lignes) and not lignes[k].strip():
                k += 1
            if k < len(lignes) and _indent(lignes[k]) > base and not (
                    libre[k] and _TITRE.match(lignes[k])):
                j = k
                continue
            return j
        if libre[j] and _TITRE.match(l):
            return j
        if _indent(l) <= base:
            return j
        j += 1
    return j


def _descendre(bloc):
    """Descend chaque titre d'un niveau (hors code) pour l'archive."""
    out, code = [], False
    for l in bloc:
        if _CLOTURE.match(l):
            code = not code
        if not code and _TITRE.match(l) and not l.startswith('######'):
            l = '#' + l
        out.append(l)
    return out


def archiver(texte, date):
    lignes = texte.split('\n')
    libre = _hors_code(lignes)

    # Découpage : domaines `# N.` et entrées `##` (de leur titre au titre
    # `#`/`##` suivant).
    entrees = []  # (debut, fin, titre, domaine)
    domaine = None
    courant = None
    for i, l in enumerate(lignes):
        m = _TITRE.match(l) if libre[i] else None
        if not m or len(m.group(1)) > 2:
            continue
        if courant:
            entrees.append((*courant, i))
            courant = None
        if len(m.group(1)) == 1:
            domaine = m.group(2) if _DOMAINE.match(m.group(2)) else None
        elif domaine:
            courant = (i, m.group(2), domaine)
    if courant:
        entrees.append((*courant, len(lignes)))

    a_retirer = set()        # indices de lignes qui quittent la liste
    renvois = {}             # indice -> ligne de renvoi insérée à sa place
    archive = {}             # domaine -> liste de blocs
    entieres = partielles = cases = 0

    for debut, titre, dom, fin in entrees:
        idx = range(debut, fin)
        ouvertes = sum(1 for k in idx if libre[k] and _OUVERTE.match(lignes[k]))
        cochees = [k for k in idx if libre[k] and _COCHEE.match(lignes[k])]
        if not cochees:
            continue
        if not ouvertes:
            a_retirer.update(idx)
            bloc = lignes[debut:fin]
            while bloc and bloc[-1].strip() in ('', '---'):
                bloc.pop()
            archive.setdefault(dom, []).append(_descendre(bloc))
            entieres += 1
            cases += len(cochees)
            continue
        pris = []
        k = debut
        while k < fin:
            if libre[k] and _COCHEE.match(lignes[k]) and k not in a_retirer:
                j = min(_fin_item(lignes, k, libre), fin)
                if not any(libre[x] and _OUVERTE.match(lignes[x]) for x in range(k, j)):
                    pris.append((k, j))
                    k = j
                    continue
            k += 1
        if not pris:
            continue
        n = sum(1 for a, b in pris for x in range(a, b)
                if libre[x] and _COCHEE.match(lignes[x]))
        bloc = [f'## {titre}', '',
                '*Entrée encore ouverte dans la liste : ici, seulement ses cases '
                'vérifiées.*', '']
        for a, b in pris:
            a_retirer.update(range(a, b))
            bloc += lignes[a:b]
        premier = pris[0][0]
        pad = ' ' * _indent(lignes[premier])
        renvois[premier] = (
            f'{pad}- ✔ {n} case{"s" if n > 1 else ""} déjà vérifiée'
            f'{"s" if n > 1 else ""} : archivée{"s" if n > 1 else ""} dans '
            f'[TESTS_APPAREIL_FAITS.md](TESTS_APPAREIL_FAITS.md) (« {titre} »).')
        archive.setdefault(dom, []).append(_descendre(bloc))
        partielles += 1
        cases += n

    liste = []
    for i, l in enumerate(lignes):
        if i in renvois:
            liste.append(renvois[i])
        if i not in a_retirer:
            liste.append(l)

    section = [f'# Archivage du {date}', '']
    for dom, blocs in archive.items():
        section += [f'## {dom}', '']
        for b in blocs:
            while b and not b[-1].strip():
                b.pop()
            section += b + ['', '---', '']
    return '\n'.join(liste), '\n'.join(section), (entieres, partielles, cases)


def main():
    essai = '--dry-run' in sys.argv[1:]
    brut = LISTE.read_bytes().decode('utf-8')
    eol = '\r\n' if '\r\n' in brut else '\n'
    texte = brut.replace('\r\n', '\n')
    if any(l.startswith(('<<<<<<<', '>>>>>>>')) for l in texte.split('\n')):
        print('conflit de fusion non résolu -- rien touché')
        return 1
    date = datetime.date.today().isoformat()
    liste, section, (entieres, partielles, cases) = archiver(texte, date)
    print(f'{entieres} entrées entières, {cases} cases '
          f'(dont celles de {partielles} entrées encore ouvertes)')
    if essai or not cases:
        return 0
    if ARCHIVE.exists():
        ancien = ARCHIVE.read_bytes().decode('utf-8').replace('\r\n', '\n').rstrip('\n')
    else:
        ancien = ENTETE_ARCHIVE.rstrip('\n')
    # Le plus récent en tête, juste après l'en-tête de l'archive.
    tete, sep, reste = ancien.partition('\n# Archivage du ')
    neuf = tete.rstrip('\n') + '\n\n' + section.rstrip('\n') + '\n'
    if sep:
        neuf += '\n# Archivage du ' + reste + '\n'
    ARCHIVE.write_bytes(neuf.replace('\n', eol).encode('utf-8'))
    LISTE.write_bytes(liste.replace('\n', eol).encode('utf-8'))
    subprocess.run([sys.executable, str(RACINE / 'tools' / 'index_tests_appareil.py')],
                   check=True)
    return 0


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(main())
