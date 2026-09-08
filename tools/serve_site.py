#!/usr/bin/env python3
"""Sert public/ en local en rejouant les réécritures de Firebase Hosting.

Sans ces réécritures, un test local ne voit jamais ce que voit un visiteur :
`/privacy-policy` tombe en 404 et `/feed/<id>` — le lien que l'app partage —
n'atteint jamais le panneau « Ouvrir dans l'application », qui est justement
ce qu'on veut vérifier.

    python tools/serve_site.py [port]      # défaut : 8787
"""
from __future__ import annotations

import json
import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLIC = os.path.join(ROOT, "public")

with open(os.path.join(ROOT, "firebase.json"), encoding="utf-8") as fh:
    _HOSTING = json.load(fh)["hosting"][0]
REWRITES = [(r["source"], r["destination"]) for r in _HOSTING["rewrites"]]

# Firebase devine mal le type des fichiers sans extension : on rejoue les
# en-têtes explicites du fichier de configuration.
HEADERS = {
    h["source"]: {e["key"]: e["value"] for e in h["headers"]}
    for h in _HOSTING.get("headers", [])
}


class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, path: str) -> str:
        clean = path.split("?", 1)[0].split("#", 1)[0]
        if not os.path.isfile(os.path.join(PUBLIC, clean.lstrip("/"))):
            for source, destination in REWRITES:
                if source == clean or (source == "**" and clean != "/"):
                    path = destination
                    break
        return super().translate_path(path)

    def end_headers(self) -> None:
        # Sans cela le navigateur resert la version precedente et le test porte
        # sur un fichier qui n'existe plus sur le disque.
        self.send_header("Cache-Control", "no-store")
        for source, headers in HEADERS.items():
            if self.path.split("?", 1)[0] == source:
                for key, value in headers.items():
                    self.send_header(key, value)
        super().end_headers()

    def log_message(self, fmt, *args):  # moins bavard
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    handler = partial(Handler, directory=PUBLIC)
    print(f"public/ servi sur http://localhost:{port} (réécritures Firebase actives)")
    ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
