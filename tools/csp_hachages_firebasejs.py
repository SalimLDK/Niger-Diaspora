"""Calcule les hachages CSP (`'sha256-…'`) des scripts inline que FlutterFire
injecte au démarrage d'un build web, et les pose dans la CSP de la cible
Hosting `admin` de firebase.json.

Pourquoi : `firebase_core_web` ne charge pas le SDK JS par un `<script src>`
mais par un script **inline** par plugin —

    window.ff_trigger_firebase_auth = async (callback) => {
      console.debug("Initializing Firebase firebase_auth");
      callback(await import("https://www.gstatic.com/firebasejs/<v>/firebase-auth.js"));
    };

— un par plugin FlutterFire du pubspec (onze aujourd'hui), qu'une CSP sans
`'unsafe-inline'` refuse : « Executing inline script violates … script-src »,
onze fois, et le panneau reste blanc (mesuré le 2026-10-14). Le texte exact,
donc le hachage, dépend de la version du SDK JS (`supportedFirebaseJsSdkVersion`
de firebase_core_web) ET du navigateur : deux gabarits, avec Trusted Types
(Chrome, Edge) ou sans (Firefox, Safari). On liste les deux séries.

Tout est lu sur le poste : versions dans pubspec.lock, gabarits et version du
SDK dans le cache pub, noms de service dans chaque plugin `*_web`. Donc après
toute montée de version FlutterFire :

    python tools/csp_hachages_firebasejs.py --ecrire   # met firebase.json à jour
    python tools/csp_hachages_firebasejs.py --verifier # exit 1 si firebase.json est en retard

Sans option : affiche les hachages. Vérifié le 2026-10-14 : les onze hachages
« Trusted Types » calculés ici sont ceux que Chrome affichait dans ses refus.
"""

import base64
import hashlib
import json
import os
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
FIREBASE_JSON = RACINE / "firebase.json"
PUBSPEC_LOCK = RACINE / "pubspec.lock"


def cache_pub() -> Path:
    env = os.environ.get("PUB_CACHE")
    if env:
        return Path(env) / "hosted" / "pub.dev"
    if os.name == "nt":
        return Path(os.environ["LOCALAPPDATA"]) / "Pub" / "Cache" / "hosted" / "pub.dev"
    return Path.home() / ".pub-cache" / "hosted" / "pub.dev"


def versions_lock() -> dict:
    """{paquet: version} pour chaque paquet du pubspec.lock."""
    out = {}
    bloc = re.compile(r'^  ([a-z0-9_]+):\n(?:    .*\n)*?    version: "([^"]+)"', re.M)
    for m in bloc.finditer(PUBSPEC_LOCK.read_text(encoding="utf-8").replace("\r\n", "\n")):
        out[m.group(1)] = m.group(2)
    return out


def gabarits(source_core: str) -> list:
    """Les deux littéraux `'''…'''` de firebase_core_web qui portent
    `ff_trigger_`, avec la règle Dart : le saut de ligne qui suit immédiatement
    `'''` n'est pas dans la chaîne."""
    out = []
    for m in re.finditer(r"'''(.*?)'''", source_core, re.S):
        texte = m.group(1)
        if "ff_trigger_" not in texte:
            continue
        if texte.startswith("\n"):
            texte = texte[1:]
        out.append(texte)
    if len(out) != 2:
        raise SystemExit(
            f"{len(out)} gabarit(s) ff_trigger_ trouvé(s) dans firebase_core_web, 2 attendus : "
            "le plugin a changé, relire injectSrcScript() et adapter ce script."
        )
    return out


def services(versions: dict, cache: Path) -> list:
    """[(windowVar, url)] : core, puis chaque plugin FlutterFire web du lock,
    dans l'ordre où `registerService` les déclare (nom, surcharge)."""
    appel = re.compile(r"registerService\(\s*'([^']+)'(?:\s*,\s*productNameOverride:\s*'([^']+)')?")
    out = [("core", "app")]
    for paquet, version in sorted(versions.items()):
        if paquet == "firebase_core_web" or not paquet.endswith("_web"):
            continue
        if not (paquet.startswith("firebase_") or paquet.startswith("cloud_")):
            continue
        lib = cache / f"{paquet}-{version}" / "lib"
        if not lib.is_dir():
            continue
        for fichier in lib.rglob("*.dart"):
            m = appel.search(fichier.read_text(encoding="utf-8", errors="replace"))
            if m:
                nom, surcharge = m.group(1), m.group(2)
                out.append((surcharge or nom, nom))
                break
    return out


def hachages() -> list:
    versions = versions_lock()
    cache = cache_pub()
    v_core = versions.get("firebase_core_web")
    if not v_core:
        raise SystemExit("firebase_core_web absent du pubspec.lock.")
    src = cache / f"firebase_core_web-{v_core}" / "lib" / "src"
    if not src.is_dir():
        raise SystemExit(f"{src} absent : lancer `flutter pub get` d'abord.")
    source_core = (src / "firebase_core_web.dart").read_text(encoding="utf-8")
    m = re.search(r"supportedFirebaseJsSdkVersion\s*=\s*'([^']+)'", (src / "firebase_sdk_version.dart").read_text(encoding="utf-8"))
    if not m:
        raise SystemExit("supportedFirebaseJsSdkVersion introuvable.")
    sdk = m.group(1)
    out = []
    for gabarit in gabarits(source_core):
        for surcharge, nom in services(versions, cache):
            window_var = f"firebase_{surcharge}"
            url = f"https://www.gstatic.com/firebasejs/{sdk}/firebase-{nom}.js"
            texte = gabarit.replace("$windowVar", window_var).replace("$stringUrl", url)
            digest = base64.b64encode(hashlib.sha256(texte.encode("utf-8")).digest()).decode()
            out.append((window_var, f"'sha256-{digest}'"))
    print(f"firebase_core_web {v_core}, SDK JS {sdk}, {len(out) // 2} plugins × 2 gabarits", file=sys.stderr)
    return out


def csp_admin(config: dict) -> dict:
    admin = next(h for h in config["hosting"] if h.get("target") == "admin")
    for regle in admin["headers"]:
        for entete in regle["headers"]:
            if entete["key"].lower() == "content-security-policy":
                return entete
    raise SystemExit("Aucune Content-Security-Policy sur la cible admin.")


def script_src_avec(csp: str, nouveaux: list) -> str:
    directives = [d.strip() for d in csp.split(";") if d.strip()]
    for i, d in enumerate(directives):
        if d.startswith("script-src "):
            sources = [s for s in d.split()[1:] if not s.startswith("'sha256-")]
            directives[i] = " ".join(["script-src", *sources, *nouveaux])
            return "; ".join(directives)
    raise SystemExit("Pas de script-src dans la CSP admin.")


def main() -> None:
    liste = hachages()
    valeurs = [h for _, h in liste]
    if "--ecrire" in sys.argv or "--verifier" in sys.argv:
        brut = FIREBASE_JSON.read_text(encoding="utf-8")
        config = json.loads(brut)
        entete = csp_admin(config)
        attendu = script_src_avec(entete["value"], valeurs)
        if "--verifier" in sys.argv:
            if entete["value"] == attendu:
                print("firebase.json : hachages à jour.")
                return
            raise SystemExit("firebase.json : hachages en retard — lancer --ecrire.")
        entete["value"] = attendu
        FIREBASE_JSON.write_text(json.dumps(config, indent=4, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        print(f"firebase.json : {len(valeurs)} hachages posés dans script-src.")
        return
    for window_var, h in liste:
        print(f"{window_var:28} {h}")


if __name__ == "__main__":
    main()
