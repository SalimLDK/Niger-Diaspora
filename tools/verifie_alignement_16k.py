#!/usr/bin/env python3
"""Verifie que les bibliotheques natives 64 bits sont alignees sur 16 Ko.

Google Play exige, pour toute app qui cible Android 15+ (API 35+) et embarque
du code natif, que chaque segment PT_LOAD des .so 64 bits ait un p_align >=
16384. Une lib alignee sur 4 Ko passe la compilation, passe l'installation,
et n'est refusee qu'au depot sur la Play Console.

Usage :
    python tools/verifie_alignement_16k.py build/app/outputs/bundle/release/app-release.aab
    python tools/verifie_alignement_16k.py chemin/vers/une/lib.so
    python tools/verifie_alignement_16k.py chemin/vers/un.aar

Code de sortie 0 si tout est conforme, 1 sinon.
"""

import os
import struct
import sys
import zipfile

SEUIL = 16 * 1024
PT_LOAD = 1

# Les .so 32 bits (armeabi-v7a, x86) ne sont pas concernes par l'exigence.
ABIS_64 = ("arm64-v8a", "x86_64")


def alignement_minimal(donnees):
    """Rend le p_align minimal des segments PT_LOAD d'un ELF 64 bits.

    Rend None si le blob n'est pas un ELF 64 bits little-endian.
    """
    if len(donnees) < 64 or donnees[:4] != b"\x7fELF":
        return None
    if donnees[4] != 2:  # EI_CLASS : 2 = ELF64
        return None
    if donnees[5] != 1:  # EI_DATA : 1 = little-endian
        return None

    e_phoff = struct.unpack_from("<Q", donnees, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", donnees, 0x36)[0]
    e_phnum = struct.unpack_from("<H", donnees, 0x38)[0]

    aligns = []
    for i in range(e_phnum):
        base = e_phoff + i * e_phentsize
        if base + e_phentsize > len(donnees):
            break
        p_type = struct.unpack_from("<I", donnees, base)[0]
        if p_type != PT_LOAD:
            continue
        aligns.append(struct.unpack_from("<Q", donnees, base + 48)[0])

    return min(aligns) if aligns else None


def abi_du_chemin(chemin):
    """Extrait l'ABI d'un chemin du type .../lib/arm64-v8a/libfoo.so."""
    parties = chemin.replace("\\", "/").split("/")
    for partie in reversed(parties):
        if partie in ABIS_64 or partie in ("armeabi-v7a", "x86", "mips"):
            return partie
    return "?"


def collecte_depuis_archive(chemin):
    """Rend [(nom affiche, contenu)] pour chaque .so d'une archive zip.

    Couvre l'AAB (base/lib/<abi>/*.so), l'APK (lib/<abi>/*.so) et l'AAR
    (jni/<abi>/*.so).
    """
    entrees = []
    with zipfile.ZipFile(chemin) as z:
        for info in z.infolist():
            if not info.filename.endswith(".so"):
                continue
            entrees.append((info.filename, z.read(info)))
    return entrees


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2

    cibles = []
    for chemin in argv[1:]:
        if chemin.endswith(".so"):
            with open(chemin, "rb") as f:
                cibles.append((chemin, f.read()))
        elif zipfile.is_zipfile(chemin):
            cibles.extend(collecte_depuis_archive(chemin))
        else:
            print("ignore (ni .so ni archive) : %s" % chemin)

    if not cibles:
        print("Aucune bibliotheque native trouvee.")
        return 1

    echecs = 0
    ignores = 0
    lignes = []
    for nom, donnees in sorted(cibles):
        abi = abi_du_chemin(nom)
        if abi not in ABIS_64 and abi != "?":
            ignores += 1
            continue
        align = alignement_minimal(donnees)
        if align is None:
            # 32 bits, ou blob non ELF : hors perimetre de l'exigence.
            ignores += 1
            continue
        conforme = align >= SEUIL
        if not conforme:
            echecs += 1
        lignes.append(
            "  %-4s %-8s %s (%s)"
            % (
                "OK" if conforme else "NON",
                "%d Ko" % (align // 1024) if align >= 1024 else "%d o" % align,
                os.path.basename(nom),
                abi,
            )
        )

    for ligne in lignes:
        print(ligne)
    print(
        "\n%d bibliotheque(s) 64 bits examinee(s), %d non conforme(s)"
        " (%d ignoree(s) : 32 bits ou non ELF64)."
        % (len(lignes), echecs, ignores)
    )
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
