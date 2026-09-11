"""Régénère le sommaire de TESTS_APPAREIL_A_FAIRE.md.

Le sommaire vit entre les balises `<!-- sommaire:debut -->` et
`<!-- sommaire:fin -->`. Il liste, domaine par domaine (titres `# N.`), les
entrées qui ont encore des cases à cocher, puis celles qui n'en ont plus.

    python tools/index_tests_appareil.py           # réécrit le sommaire
    python tools/index_tests_appareil.py --check   # sort en 1 s'il est périmé
"""
import re
import sys
from pathlib import Path

FICHIER = Path(__file__).resolve().parent.parent / 'TESTS_APPAREIL_A_FAIRE.md'
DEBUT = '<!-- sommaire:debut -->'
FIN = '<!-- sommaire:fin -->'

_CLOTURE = re.compile(r'^\s*(```|~~~)')
_TITRE = re.compile(r'^(#{1,6}) (.+?)\s*$')
_DOMAINE = re.compile(r'^\d+\. ')
_OUVERTE = re.compile(r'^\s*[-*] \[ \]')
_COCHEE = re.compile(r'^\s*[-*] \[[xX]\]')


def _ancre(titre, deja_vues):
    """Ancre telle que GitHub la calcule ; les doublons prennent -1, -2…"""
    base = re.sub(r'[^\w\- ]', '', titre.strip().lower()).replace(' ', '-')
    n = deja_vues.get(base, 0)
    deja_vues[base] = n + 1
    return base if n == 0 else f'{base}-{n}'


def _domaines(lignes):
    """Domaines et entrées dans l'ordre du fichier, avec leurs compteurs."""
    vues = {}
    domaines = []
    entree = None
    dans_code = False
    dans_sommaire = False
    for ligne in lignes:
        if ligne.strip() == DEBUT:
            dans_sommaire = True
            continue
        if ligne.strip() == FIN:
            dans_sommaire = False
            continue
        if dans_sommaire:
            continue
        if _CLOTURE.match(ligne):
            dans_code = not dans_code
            continue
        if dans_code:
            continue
        m = _TITRE.match(ligne)
        if m:
            niveau, titre = len(m.group(1)), m.group(2)
            ancre = _ancre(titre, vues)
            if niveau == 1:
                entree = None
                if _DOMAINE.match(titre):
                    domaines.append({'titre': titre, 'ancre': ancre, 'entrees': []})
            elif niveau == 2 and domaines:
                entree = {'titre': titre, 'ancre': ancre, 'ouvertes': 0, 'cochees': 0}
                domaines[-1]['entrees'].append(entree)
            continue
        if entree is not None:
            if _OUVERTE.match(ligne):
                entree['ouvertes'] += 1
            elif _COCHEE.match(ligne):
                entree['cochees'] += 1
    return domaines


def _lien(titre, ancre):
    texte = titre.replace('[', '\\[').replace(']', '\\]')
    return f'[{texte}](#{ancre})'


def _sommaire(domaines):
    entrees = [e for d in domaines for e in d['entrees']]
    ouvertes = sum(e['ouvertes'] for e in entrees)
    cochees = sum(e['cochees'] for e in entrees)
    out = [
        DEBUT,
        '<!-- Généré par tools/index_tests_appareil.py : ne pas éditer à la main. -->',
        '',
        f'**{ouvertes} cases à cocher, {cochees} cochées**, '
        f'réparties dans {len(entrees)} entrées.',
        '',
    ]
    for d in domaines:
        o = sum(e['ouvertes'] for e in d['entrees'])
        c = sum(e['cochees'] for e in d['entrees'])
        out += [f'**{_lien(d["titre"], d["ancre"])}** — {o} à faire, {c} faites', '']
        for e in d['entrees']:
            if e['ouvertes']:
                out.append(f'- {e["ouvertes"]} · {_lien(e["titre"], e["ancre"])}')
        soldees = [e for e in d['entrees'] if not e['ouvertes']]
        if soldees:
            out.append('- sans case ouverte :')
            out += [f'  - {_lien(e["titre"], e["ancre"])}' for e in soldees]
        out.append('')
    out.append(FIN)
    return out


def regenerer(texte):
    # Garde les fins de ligne du fichier : CRLF dans un checkout autocrlf.
    eol = '\r\n' if '\r\n' in texte else '\n'
    lignes = texte.replace('\r\n', '\n').split('\n')
    try:
        debut = next(i for i, l in enumerate(lignes) if l.strip() == DEBUT)
        fin = next(i for i, l in enumerate(lignes) if l.strip() == FIN)
    except StopIteration:
        raise SystemExit(f'balises {DEBUT} / {FIN} introuvables')
    return eol.join(lignes[:debut] + _sommaire(_domaines(lignes)) + lignes[fin + 1:])


def main():
    verifier = '--check' in sys.argv[1:]
    chemins = [a for a in sys.argv[1:] if not a.startswith('--')]
    fichier = Path(chemins[0]) if chemins else FICHIER
    with open(fichier, encoding='utf-8', newline='') as f:
        texte = f.read()
    neuf = regenerer(texte)
    if neuf == texte:
        print('sommaire a jour')
        return 0
    if verifier:
        print('sommaire perime : lancer python tools/index_tests_appareil.py')
        return 1
    with open(fichier, 'w', encoding='utf-8', newline='') as f:
        f.write(neuf)
    print('sommaire regenere')
    return 0


if __name__ == '__main__':
    sys.exit(main())
