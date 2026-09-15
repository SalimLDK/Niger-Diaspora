#!/usr/bin/env python3
"""Ce que la forme de la donnee dit des ecritures qui ont echoue.

POURQUOI CE FICHIER EXISTE

Une ecriture refusee ne laisse pas toujours une erreur. Cote Firestore un lot
atomique echoue en entier et ne laisse RIEN -- accepter une demande d'ami etait
impossible depuis des mois, personne ne le savait. Cote Supabase c'est pire :
un UPDATE qui ne matche aucune ligne rend **200**, et une lecture refusee par
la RLS **reussit a vide**. Il n'y a rien a attraper, rien a journaliser.

Ce qui reste, dans les deux cas, c'est la trace dans la donnee : une table
fille systematiquement vide, un miroir qui n'a qu'un cote, un compteur fige. Le
defaut des sondages a ete trouve comme ca -- « 6 sondages, dont 6 sans option ».

Ce script pose ces questions-la, en une passe.

USAGE

    python tools/invariants_donnees.py            # rapport
    python tools/invariants_donnees.py --sql      # imprime le SQL, n'execute rien

⚠️ **Ne pas passer la sortie dans un `| tail`.** Le code de sortie d'un
pipeline est celui de la DERNIERE commande : `tail` rend toujours 0, et une
panne de connexion se lit alors comme un balayage reussi. Paye le 2026-09-14,
le jour meme ou cet outil a ete ecrit pour traquer les succes qui n'ont rien
fait. Rediriger dans un fichier, puis le lire :

    python tools/invariants_donnees.py > /tmp/balayage.txt 2>&1; echo $?

Sort en erreur si une CONDITION est violee. Les MESURES ne font jamais echouer :
elles donnent un ordre de grandeur, et c'est au lecteur de trancher -- meme
partage que `tools/rules_tests/signalisation_appels.mjs`. Un garde qui crie a
tort finit desactive.

DEUX PIEGES DEJA PAYES

- `supabase db query --linked` se connecte en `postgres`, qui contourne la RLS
  (`rolbypassrls`). C'est exactement ce qu'on veut ICI -- on veut la verite de
  la donnee, pas ce qu'un role en voit. Mais ne jamais confondre ce script avec
  un test de policy : pour ca il faut `SET LOCAL ROLE authenticated`.
- Plusieurs tables de ce projet n'existent dans aucune migration
  (`schema_migrations` ment, cf. la derive de schema). Le script decouvre donc
  le schema reel avant de composer ses questions, et saute en silence celles
  dont la table ou la colonne manque -- en le disant a la fin.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass, field

CONDITION = "condition"
MESURE = "mesure"


@dataclass(frozen=True)
class Invariant:
    cle: str
    domaine: str
    genre: str
    besoin: tuple[str, ...]  # "table" ou "table.colonne"
    sql: str
    libelle: str
    sens: str  # ce qu'un resultat non nul veut dire
    field_: None = field(default=None, repr=False)


INVARIANTS: tuple[Invariant, ...] = (
    # -- Ecritures symetriques : les deux cotes, ou rien -----------------------
    Invariant(
        "amities_sens_unique",
        "Amities",
        CONDITION,
        ("friends.user_id", "friends.friend_id"),
        """SELECT count(*) FROM friends f
           WHERE NOT EXISTS (SELECT 1 FROM friends g
                             WHERE g.user_id = f.friend_id
                               AND g.friend_id = f.user_id)""",
        "amities a sens unique",
        "une acceptation n'a ecrit qu'un cote, ou le miroir "
        "`mirrorFriendToSupabase` n'a tourne que pour une des deux lignes. "
        "L'ami ne voit PAS les publications « Amis » : la regle du projet est "
        "« ami = l'auteur a la personne dans SES amis ».",
    ),
    Invariant(
        "amities_total",
        "Amities",
        MESURE,
        ("friends",),
        "SELECT count(*) FROM friends",
        "lignes dans `friends` (2 par amitie)",
        "un nombre impair est impossible si tout va bien ; zero apres des mois "
        "d'usage signifie que le miroir n'a jamais tourne.",
    ),
    Invariant(
        "blocages_total",
        "Blocages",
        MESURE,
        ("blocked_users",),
        "SELECT count(*) FROM blocked_users",
        "lignes dans `blocked_users`",
        "zero alors que la fonctionnalite est livree depuis des mois confirme "
        "que `blockUser` n'ecrit rien : son lot Firestore leve avant "
        "`_refleterDansSupabase`, appele APRES `batch.commit()`.",
    ),
    Invariant(
        "abonnements_total",
        "Abonnements",
        MESURE,
        ("user_follows",),
        "SELECT count(*) FROM user_follows",
        "lignes dans `user_follows`",
        "contexte : les abonnements sont une relation a sens unique, donc "
        "aucun invariant de symetrie ne s'y applique.",
    ),
    # -- Ecritures en deux temps : parent puis enfant --------------------------
    Invariant(
        "groupes_sans_membre",
        "Groupes",
        CONDITION,
        ("groups.id", "group_members.group_id"),
        """SELECT count(*) FROM groups g
           WHERE NOT EXISTS (SELECT 1 FROM group_members m
                             WHERE m.group_id = g.id)""",
        "groupes sans aucun membre",
        "la creation a ecrit le groupe mais pas l'adhesion de son createur : "
        "un groupe que personne n'administre et que personne ne voit.",
    ),
    Invariant(
        "groupes_createur_non_membre",
        "Groupes",
        CONDITION,
        ("groups.creator_id", "group_members.user_id"),
        """SELECT count(*) FROM groups g
           WHERE NOT EXISTS (SELECT 1 FROM group_members m
                             WHERE m.group_id = g.id
                               AND m.user_id = g.creator_id)""",
        "groupes dont le createur n'est pas membre",
        "variante plus fine de la precedente : le groupe a des membres, mais "
        "la ligne du createur manque.",
    ),
    Invariant(
        "groupes_compteur_faux",
        "Groupes",
        CONDITION,
        ("groups.member_count", "group_members.group_id"),
        """SELECT count(*) FROM groups g
           WHERE g.member_count <> (SELECT count(*) FROM group_members m
                                    WHERE m.group_id = g.id)""",
        "groupes dont `member_count` ment",
        "le trigger de comptage a touche 0 ligne sans erreur -- la forme "
        "exacte du defaut des compteurs de sondage : un trigger qui n'est pas "
        "`SECURITY DEFINER` subit la RLS de l'appelant.",
    ),
    Invariant(
        "sondages_sans_option",
        "Sondages",
        CONDITION,
        ("post_polls.id", "post_poll_options.poll_id"),
        """SELECT count(*) FROM post_polls p
           WHERE NOT EXISTS (SELECT 1 FROM post_poll_options o
                             WHERE o.poll_id = p.id)""",
        "sondages sans aucune option",
        "l'ecriture des options est refusee (RLS active sans policy INSERT). "
        "C'est le defaut corrige le 2026-08-23 : cette ligne verifie qu'il "
        "n'est pas revenu.",
    ),
    Invariant(
        "stories_close_sans_liste",
        "Stories",
        CONDITION,
        ("stories.audience", "stories.author_id",
         "story_audience_members.owner_id", "story_audience_members.list"),
        """SELECT count(*) FROM stories s
           WHERE s.audience = 'close'
             AND NOT EXISTS (SELECT 1 FROM story_audience_members m
                             WHERE m.owner_id = s.author_id
                               AND m.list = 'close')""",
        "stories « amis proches » sans liste d'amis proches",
        "l'audience a ete choisie mais la liste n'a jamais ete ecrite : la "
        "story n'est visible par PERSONNE, sans que rien ne le signale.",
    ),
    Invariant(
        "evenements_audience_vide",
        "Evenements",
        CONDITION,
        ("events.id", "events.visibility", "event_audience.event_id"),
        """SELECT count(*) FROM events e
           WHERE e.visibility IS NOT NULL
             AND e.visibility NOT IN ('public')
             AND NOT EXISTS (SELECT 1 FROM event_audience a
                             WHERE a.event_id = e.id)""",
        "evenements a audience restreinte, sans audience",
        "`set_event_audience` n'a pas ecrit : l'evenement est restreint a un "
        "ensemble vide.",
    ),
    # -- Compteurs denormalises ------------------------------------------------
    Invariant(
        "publications_like_count_faux",
        "Fil",
        CONDITION,
        ("posts.like_count", "post_likes.post_id"),
        """SELECT count(*) FROM posts p
           WHERE p.like_count <> (SELECT count(*) FROM post_likes l
                                  WHERE l.post_id = p.id)""",
        "publications dont `like_count` ment",
        "meme famille que `member_count` : un compteur fige est un « bug "
        "d'affichage » qui n'en est pas un, c'est une ecriture refusee.",
    ),
    Invariant(
        "publications_comment_count_faux",
        "Fil",
        CONDITION,
        ("posts.comment_count", "post_comments.post_id"),
        """SELECT count(*) FROM posts p
           WHERE p.comment_count <> (SELECT count(*) FROM post_comments c
                                     WHERE c.post_id = p.id)""",
        "publications dont `comment_count` ment",
        "idem.",
    ),
    Invariant(
        "evenements_compteur_ecart",
        "Evenements",
        MESURE,
        ("events.attendee_count", "event_attendees.event_id",
         "event_attendees.status"),
        """SELECT count(*) FROM events e
           WHERE e.attendee_count <> (SELECT count(*) FROM event_attendees a
                                      WHERE a.event_id = e.id
                                        AND a.status = 'going')""",
        "evenements dont `attendee_count` s'ecarte des « going »",
        "MESURE et non condition : on ne sait pas avec certitude si le "
        "compteur est cense inclure les « maybe ». Un ecart massif designe "
        "quand meme un trigger muet.",
    ),
    Invariant(
        "podcasts_compteur_faux",
        "Podcasts",
        MESURE,
        ("podcasts.episode_count", "podcast_episodes.podcast_id"),
        """SELECT count(*) FROM podcasts p
           WHERE p.episode_count <> (SELECT count(*) FROM podcast_episodes e
                                     WHERE e.podcast_id = p.id)""",
        "podcasts dont `episode_count` ment",
        "meme famille ; en mesure car la fonctionnalite est peu utilisee.",
    ),
    # -- Identite : le pont Firebase -> Supabase -------------------------------
    Invariant(
        "comptes_sans_pont",
        "Identite",
        MESURE,
        ("users.id", "users.email", "auth_mappings.firebase_uid"),
        """SELECT count(*) FROM users u
           WHERE NOT EXISTS (SELECT 1 FROM auth_mappings m
                             WHERE m.firebase_uid = u.id)
             AND COALESCE(u.email, '') NOT LIKE '%@example.com'""",
        "VRAIS comptes sans correspondance dans `auth_mappings`",
        "ces comptes n'ont jamais abouti l'echange Firebase -> Supabase. "
        "Toute ecriture faite pour eux part en `anon`, et toute lecture "
        "reussit a vide au lieu d'echouer. Comparer la date de creation au "
        "2026-09-09, jour du correctif du pont : au-dela, c'est une "
        "regression ; en deca, c'est de l'heritage.",
    ),
    Invariant(
        "comptes_sonde_residuels",
        "Identite",
        MESURE,
        ("users.id", "users.email"),
        """SELECT count(*) FROM users u
           WHERE COALESCE(u.email, '') LIKE '%@example.com'""",
        "comptes de sonde restes dans `public.users`",
        "residus des bancs (`sonde_echange_auth.mjs` et la verification du "
        "pont) : ils ne sont PAS une panne. `purge_comptes_sonde.mjs` efface "
        "l'utilisateur gotrue et Firebase, ce qui fait tomber `auth_mappings` "
        "par cascade, mais laisse la ligne `public.users` — d'ou des comptes "
        "« sans pont » qui apparaissent SANS qu'aucun vrai compte n'ait "
        "echoue. C'est ce qui a produit une fausse alerte le 2026-09-15.",
    ),
)


def executer(sql: str) -> list[dict]:
    """Lance une requete par la CLI Supabase et rend les lignes."""
    binaire = shutil.which("supabase")
    if not binaire:
        sys.exit(
            "`supabase` introuvable dans le PATH.\n"
            "Sur ce poste il vit dans ~/scoop/shims."
        )
    proc = subprocess.run(
        [binaire, "db", "query", "--linked", "--output", "json", sql],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        sys.exit(
            "La requete a echoue :\n"
            + (proc.stderr or proc.stdout).strip()
            + "\n\nSi c'est « Cannot find project ref », copier "
            "`supabase/.temp/` depuis le depot principal (cf. CLAUDE.md)."
        )
    return _lignes_json(proc.stdout)


def _lignes_json(sortie: str) -> list[dict]:
    """Extrait le tableau de lignes de la sortie de `db query -o json`.

    Lancee par un agent, la CLI enveloppe le JSON dans un avertissement
    « donnee non fiable » en texte libre. C'est justifie -- ce qui revient est
    ecrit par des usagers -- et on le garde : on cherche donc le tableau JSON
    dans la sortie plutot que d'exiger qu'elle soit du JSON pur, et on n'en lit
    que des entiers.
    """
    sortie = sortie.strip()
    if not sortie:
        return []
    # La CLI encadre le JSON de lignes de texte libre (« Initialising login
    # role... », l'avis de mise a jour) : on isole l'objet.
    debut, fin = sortie.find("{"), sortie.rfind("}")
    if debut == -1 or fin <= debut:
        sys.exit("Sortie inattendue de la CLI :\n" + sortie[:2000])
    try:
        charge = json.loads(sortie[debut:fin + 1])
    except json.JSONDecodeError:
        sys.exit("Sortie inattendue de la CLI :\n" + sortie[:2000])
    if isinstance(charge, list):
        return charge
    return charge.get("rows", [])


def schema_reel() -> set[str]:
    """`{'table', 'table.colonne', ...}` reellement presents dans public."""
    lignes = executer(
        "SELECT table_name, column_name FROM information_schema.columns "
        "WHERE table_schema = 'public'"
    )
    presents: set[str] = set()
    for l in lignes:
        table = l["table_name"]
        presents.add(table)
        presents.add(f"{table}.{l['column_name']}")
    return presents


def composer(applicables: tuple[Invariant, ...]) -> str:
    morceaux = [
        f"SELECT '{inv.cle}' AS cle, ({' '.join(inv.sql.split())})::BIGINT AS n"
        for inv in applicables
    ]
    return "\nUNION ALL\n".join(morceaux)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sql", action="store_true",
                    help="imprime le SQL compose et sort, sans rien executer")
    args = ap.parse_args()

    if args.sql:
        print(composer(INVARIANTS))
        return 0

    presents = schema_reel()
    applicables = tuple(
        inv for inv in INVARIANTS
        if all(besoin in presents for besoin in inv.besoin)
    )
    sautes = [inv for inv in INVARIANTS if inv not in applicables]

    if not applicables:
        print("Aucun invariant applicable : le schema lu est vide.")
        return 1

    resultats = {l["cle"]: int(l["n"]) for l in executer(composer(applicables))}

    violations = []
    domaine_courant = None
    for inv in applicables:
        n = resultats.get(inv.cle)
        if n is None:
            continue
        if inv.domaine != domaine_courant:
            domaine_courant = inv.domaine
            print(f"\n{domaine_courant}")
        if inv.genre == CONDITION:
            marque = "  OK  " if n == 0 else " ANOMALIE"
            if n:
                violations.append((inv, n))
        else:
            marque = " mesure"
        print(f"{marque:>9}  {n:>7}  {inv.libelle}")
        if n and inv.genre == CONDITION:
            for ligne in _plier(inv.sens):
                print(f"{'':>9}           {ligne}")

    if sautes:
        print("\nSautes (table ou colonne absente du schema) :")
        for inv in sautes:
            manquants = [b for b in inv.besoin if b not in presents]
            print(f"           {inv.cle} -- manque {', '.join(manquants)}")

    print()
    if violations:
        print(f"{len(violations)} anomalie(s). Chacune designe une ecriture "
              "qui n'a pas eu lieu, sans erreur nulle part.")
        return 1
    print("Aucune anomalie sur les conditions. Les mesures restent a lire.")
    return 0


def _plier(texte: str, largeur: int = 66) -> list[str]:
    mots, lignes, courante = texte.split(), [], ""
    for mot in mots:
        if len(courante) + len(mot) + 1 > largeur:
            lignes.append(courante)
            courante = mot
        else:
            courante = f"{courante} {mot}".strip()
    if courante:
        lignes.append(courante)
    return lignes


if __name__ == "__main__":
    sys.exit(main())
