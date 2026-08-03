"""Audit d'accessibilité : quels fichiers/widgets sont atteignables depuis les
routes de l'app, et lesquels ne le sont par aucun chemin."""
import os
import re
import collections

SEP = chr(92)  # backslash

files = {}
for dp, _, fs in os.walk('lib'):
    for f in fs:
        if f.endswith('.dart'):
            p = os.path.join(dp, f).replace(SEP, '/')
            files[p] = open(p, encoding='utf-8').read()

generated = lambda p: p.endswith(('.g.dart', '.freezed.dart'))

# --- widgets définis -------------------------------------------------------
widget_def = {}
for p, txt in files.items():
    if generated(p):
        continue
    for m in re.finditer(
            r'^class (_?[A-Za-z]' + r'\w*) extends '
            r'(?:Consumer)?(?:Stateless|Stateful|Hook)Widget', txt, re.M):
        widget_def[m.group(1)] = p

# --- symboles top-level (pour le graphe) -----------------------------------
sym_def = {}
patterns = [
    r'^(?:abstract |sealed |final |base )?class ([A-Z]' + r'\w*)',
    r'^enum ([A-Z]' + r'\w*)',
    r'^mixin ([A-Z]' + r'\w*)',
    r'^(?:final|const) (' + r'\w+Provider)' + r'\b',
    r'^(?:Future<[^>]*>|void|Widget|String|bool|int|double) (' + r'\w+)' + r'\(',
    r'^extension (' + r'\w+) on',
]
for p, txt in files.items():
    for pat in patterns:
        for m in re.finditer(pat, txt, re.M):
            sym_def.setdefault(m.group(1), p)

# Membres d'extension : utilisés en `context.surfaceColor`, jamais comme
# symbole top-level. Sans eux, tout fichier qui n'expose qu'une extension
# paraît inatteignable (faux positif massif : adaptive_colors, validators…).
ext_block = re.compile(r'^extension\s+\w+\s+on\s+[^{]+\{', re.M)
for p, txt in files.items():
    for m in ext_block.finditer(txt):
        start = m.end()
        depth, i = 1, start
        while i < len(txt) and depth:
            if txt[i] == '{':
                depth += 1
            elif txt[i] == '}':
                depth -= 1
            i += 1
        block = txt[start:i]
        for mm in re.finditer(
                r'\b(?:get|set)\s+(' + r'\w+)' + r'\b', block):
            sym_def.setdefault(mm.group(1), p)
        for mm in re.finditer(
                r'^\s+(?:[\w<>?,\s]+?)\s(' + r'\w+)' + r'\s*\(', block, re.M):
            sym_def.setdefault(mm.group(1), p)

# --- `part of` : la part appartient à son parent ---------------------------
part_of = {}
for p, txt in files.items():
    m = re.match(r"\s*part of '([^']+)'", txt)
    if m:
        parent = os.path.normpath(
            os.path.join(os.path.dirname(p), m.group(1))).replace(SEP, '/')
        part_of[p] = parent


def owner(p):
    return part_of.get(p, p)


# --- graphe de références --------------------------------------------------
edges = collections.defaultdict(set)
ident = re.compile(r'\b([A-Za-z_]' + r'\w*)' + r'\b')
for p, txt in files.items():
    src = owner(p)
    body = re.sub(r'^(import|export|part).*$', '', txt, flags=re.M)
    for name in set(ident.findall(body)):
        d = sym_def.get(name)
        if d and owner(d) != src:
            edges[src].add(owner(d))

# Deux points d'entrée : l'app principale, et le back-office `admin_app`
# (lib/features/admin/main.dart) qui a son propre `runApp`.
ENTRY = ('lib/main.dart', 'lib/app.dart', 'lib/features/admin/main.dart')
roots = {owner(p) for p in files
         if p in ENTRY or p.startswith('lib/core/router/')}
missing = [e for e in ENTRY if e not in files]
if missing:
    print('!! points d entree introuvables : %s' % missing)

seen = set()
stack = list(roots)
while stack:
    c = stack.pop()
    if c in seen:
        continue
    seen.add(c)
    stack.extend(edges.get(c, ()))

own_files = [f for f in files if owner(f) == f and not generated(f)]
unreachable = sorted(f for f in own_files if f not in seen)

print('Fichiers analysés      : %d' % len(own_files))
print('Atteignables (routes)  : %d' % len([f for f in own_files if f in seen]))
print('INATTEIGNABLES         : %d' % len(unreachable))
print()
by_feature = collections.defaultdict(list)
for f in unreachable:
    parts = f.split('/')
    key = '/'.join(parts[:3]) if len(parts) > 3 else '/'.join(parts[:2])
    by_feature[key].append(f)
for k in sorted(by_feature):
    print('  [%s]' % k)
    for f in by_feature[k]:
        w = [n for n, d in widget_def.items() if d == f]
        tag = ('  widgets: ' + ', '.join(sorted(w)[:4])) if w else ''
        print('     - %s%s' % (f.split('/')[-1], tag))
