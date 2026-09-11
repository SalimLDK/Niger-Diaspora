"""Régénère le sommaire de TESTS_APPAREIL_A_FAIRE.md.

Le sommaire vit entre les balises `<!-- sommaire:debut -->` et
`<!-- sommaire:fin -->`. Il liste les entrées qui ont encore des cases à
cocher, par priorité puis par importance, puis le décompte par domaine
(titres `# N.`).

La priorité d'une entrée est la première ligne de la forme
`**Priorité P1** · importance 4/5 — raison` sous son titre. Une entrée
ouverte sans cette ligne apparaît « à classer », en tête.

    python tools/index_tests_appareil.py           # réécrit le sommaire
    python tools/index_tests_appareil.py --check   # sort en 1 s'il est périmé
"""
import re
import sys
from pathlib import Path

FICHIER = Path(__file__).resolve().parent.parent / 'TESTS_APPAREIL_A_FAIRE.md'
DEBUT = '<!-- sommaire:debut -->'
FIN = '<!-- sommaire:fin -->'

NIVEAUX = {
    'P0': 'avant toute nouvelle version',
    'P1': 'fonction importante, jamais vérifiée',
    'P2': 'fonction secondaire ou cas limite',
    'P3': 'confort, cosmétique, fonction en pause',
}

_CLOTURE = re.compile(r'^\s*(```|~~~)')
_TITRE = re.compile(r'^(#{1,6}) (.+?)\s*$')
_DOMAINE = re.compile(r'^\d+\. ')
_OUVERTE = re.compile(r'^\s*[-*] \[ \]')
_COCHEE = re.compile(r'^\s*[-*] \[[xX]\]')
_PRIORITE = re.compile(r'^\*\*Priorité (P[0-3])\*\*(?: · importance ([1-5])/5)?')


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
                entree = {'titre': titre, 'ancre': ancre, 'ouvertes': 0,
                          'cochees': 0, 'priorite': None, 'importance': 0,
                          'domaine': domaines[-1]}
                domaines[-1]['entrees'].append(entree)
            continue
        if entree is None:
            continue
        if _OUVERTE.match(ligne):
            entree['ouvertes'] += 1
        elif _COCHEE.match(ligne):
            entree['cochees'] += 1
        elif entree['priorite'] is None:
            p = _PRIORITE.match(ligne)
            if p:
                entree['priorite'] = p.group(1)
                entree['importance'] = int(p.group(2) or 0)
                entree['bloquee'] = '*Bloqué' in ligne
    return domaines


def _lien(titre, ancre):
    texte = titre.replace('[', '\\[').replace(']', '\\]')
    return f'[{texte}](#{ancre})'


def _sommaire(domaines):
    entrees = [e for d in domaines for e in d['entrees']]
    ouvertes = [e for e in entrees if e['ouvertes']]
    out = [
        DEBUT,
        '<!-- Généré par tools/index_tests_appareil.py : ne pas éditer à la main. -->',
        '',
        f'**{sum(e["ouvertes"] for e in entrees)} cases à cocher, '
        f'{sum(e["cochees"] for e in entrees)} cochées** — {len(ouvertes)} '
        f'entrées sur {len(entrees)} ont encore des cases ouvertes.',
        '',
        'Par priorité, puis par importance (le nombre en tête de ligne est '
        'celui des cases ouvertes) :',
        '',
    ]
    groupes = [(None, 'À classer : aucune ligne « Priorité » sous le titre')]
    groupes += list(NIVEAUX.items())
    for niveau, libelle in groupes:
        membres = [e for e in ouvertes if e['priorite'] == niveau]
        if not membres:
            continue
        # Tri stable : importance décroissante, puis ordre du fichier.
        membres.sort(key=lambda e: -e['importance'])
        tete = f'**{niveau} — {libelle}**' if niveau else f'**{libelle}**'
        out += [f'{tete} ({len(membres)})', '']
        for e in membres:
            out.append(f'- {e["ouvertes"]} · {_lien(e["titre"], e["ancre"])} '
                       f'· *{e["domaine"]["titre"].split(". ", 1)[1]}*'
                       + (' · bloqué' if e.get('bloquee') else ''))
        out.append('')
    out += ['Par domaine :', '']
    for d in domaines:
        o = sum(e['ouvertes'] for e in d['entrees'])
        c = sum(e['cochees'] for e in d['entrees'])
        out.append(f'- {_lien(d["titre"], d["ancre"])} — {o} à faire, {c} faites')
    out += ['', FIN]
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
