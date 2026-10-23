"""Injecte la CSP de la cible Hosting `admin` dans build/web_admin/index.html,
en balise <meta http-equiv>, pour la tester EN LOCAL sans déployer.

Pourquoi : l'émulateur Hosting (`firebase emulators:start --only hosting:admin`)
sert les fichiers mais n'applique pas les en-têtes de firebase.json (constaté
le 2026-10-14 avec firebase-tools 15.30.1). En production, Firebase Hosting
pose l'en-tête HTTP ; la balise meta n'est qu'un substitut de test — elle
ignore `frame-ancestors` (retiré ici, X-Frame-Options DENY le couvre) et les
en-têtes non-CSP (HSTS, Permissions-Policy…), que seul un `curl -I` sur le
site déployé peut vérifier.

Usage, après `bash tools/build_admin_web.sh` :
    python tools/injecter_csp_meta.py            # injecte
    python tools/injecter_csp_meta.py --retirer  # revient à l'index.html du build

Ne jamais déployer un build avec la balise injectée : la CSP serait posée deux
fois (en-tête + meta), et la plus stricte des deux l'emporterait — ici les
mêmes, donc sans effet, mais c'est un piège pour la prochaine modification.
`--retirer` avant tout `firebase deploy`, ou rebâtir.
"""

import json
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
INDEX = RACINE / "build" / "web_admin" / "index.html"
MARQUEUR = "<!-- csp-test-local -->"


def csp_de_firebase_json() -> str:
    config = json.loads((RACINE / "firebase.json").read_text(encoding="utf-8"))
    admin = next(h for h in config["hosting"] if h.get("target") == "admin")
    for regle in admin["headers"]:
        for entete in regle["headers"]:
            if entete["key"].lower() == "content-security-policy":
                return entete["value"]
    raise SystemExit("Aucune Content-Security-Policy sur la cible admin.")


def sans_frame_ancestors(csp: str) -> str:
    directives = [d.strip() for d in csp.split(";") if d.strip()]
    return "; ".join(d for d in directives if not d.startswith("frame-ancestors"))


def main() -> None:
    if not INDEX.exists():
        raise SystemExit(f"{INDEX} absent : lancer tools/build_admin_web.sh d'abord.")
    html = INDEX.read_text(encoding="utf-8")
    html = re.sub(rf"\s*{re.escape(MARQUEUR)}.*?{re.escape(MARQUEUR)}", "", html, flags=re.S)
    if "--retirer" in sys.argv:
        INDEX.write_text(html, encoding="utf-8", newline="\n")
        print("Balise meta CSP retirée.")
        return
    valeur = sans_frame_ancestors(csp_de_firebase_json()).replace('"', "&quot;")
    balise = (
        f'\n  {MARQUEUR}<meta http-equiv="Content-Security-Policy" '
        f'content="{valeur}">{MARQUEUR}'
    )
    html = html.replace("<head>", "<head>" + balise, 1)
    INDEX.write_text(html, encoding="utf-8", newline="\n")
    print("Balise meta CSP injectée dans", INDEX.relative_to(RACINE))
    print("Ouvrir http://127.0.0.1:5000 (émulateur) et lire la console : aucun « Refused to … » attendu.")


if __name__ == "__main__":
    main()
