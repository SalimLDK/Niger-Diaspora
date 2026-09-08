"""Repeint en vert le degrade orange des icones DN (2026-09-07).

Sert a rendre auditable un changement qui, sinon, n'apparait dans le diff que
comme trois PNG binaires modifies. Rejouable :

    python tools/recolore_icone_dn.py assets/import_icons/dn_ultra_minimal_icon.png ...
    dart run flutter_launcher_icons

Le sigle blanc, son anticrenelage et le canal alpha sont preserves.

Le degrade d'origine est un lineaire diagonal (SVG : 0%,0% -> 100%,100%),
verifie au pixel pres sur 10 sondages : O(x,y) = lerp(#E97424, #F59942, t)
avec t = (x/(W-1) + y/(H-1))/2. Chaque pixel vaut donc lerp(O, blanc, w) ;
on retrouve w par moindres carres sur les trois canaux, puis on repose
lerp(G, blanc, w) avec le degrade vert.
"""
import sys
from PIL import Image

ORANGE_A, ORANGE_B = (0xE9, 0x74, 0x24), (0xF5, 0x99, 0x42)
VERT_A, VERT_B = (0x00, 0x96, 0x00), (0x00, 0xC0, 0x00)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def recolore(chemin):
    im = Image.open(chemin)
    mode = im.mode
    rgba = im.convert('RGBA')
    w, h = rgba.size
    src = rgba.load()
    out = Image.new('RGBA', (w, h))
    dst = out.load()
    for y in range(h):
        fy = y / (h - 1)
        for x in range(w):
            r, g, b, a = src[x, y]
            if a == 0:
                dst[x, y] = (r, g, b, a)
                continue
            t = (x / (w - 1) + fy) / 2
            o = lerp(ORANGE_A, ORANGE_B, t)
            # w_blanc = argmin ||c - lerp(o, 255, w)||^2
            num = sum((c - oi) * (255 - oi) for c, oi in zip((r, g, b), o))
            den = sum((255 - oi) ** 2 for oi in o)
            wb = min(1.0, max(0.0, num / den))
            v = lerp(VERT_A, VERT_B, t)
            dst[x, y] = tuple(
                round(vi + (255 - vi) * wb) for vi in v
            ) + (a,)
    if mode == 'RGB':
        out = out.convert('RGB')
    out.save(chemin)
    print('repeint :', chemin)


for chemin in sys.argv[1:]:
    recolore(chemin)
