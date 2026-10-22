# Refonte de l'administration — état des lieux au 2026-10-19

Ce que la branche `claude/admin-fondations-moderation` a posé d'après les deux
documents de cadrage (« Référentiel global de l'administration » et
« Spécification complète des interfaces », v1.0 du 2026-10-16). Les modules
traités par l'autre session (`claude/admin-refonte` : membres, journal d'audit,
statistiques, ambassades, transferts et marketplace, référentiel géographique,
calendrier des événements, délais de service du support, recherche globale) ont
leurs propres notes de migration ; les listes ci-dessous ne couvrent que ce
dossier-ci.

Chaque module suit le même modèle : **les écritures passent par des fonctions
serveur** (permission, statut courant verrouillé, motif ou base obligatoire,
audit dans la même transaction), la lecture par une permission, les anciennes
écritures directes d'administrateur sont fermées, et un **banc SQL rejoué en
production sous `BEGIN … ROLLBACK`** précède chaque application.

## Modules

| Module | Migration (appliquée) | Banc | Écran du panneau |
|---|---|---|---|
| Signalements : demandes d'informations, recours | `20261018090000` | 55 cas | dossier de signalement (`dossier_moderation_sections.dart`) |
| Support : file, notes internes, réponses | `20261018130000` | 64 | `admin_support_tickets_screen.dart` |
| Démarches consulaires : brouillon → relecture → publication, versions | `20261018150000` | 77 | `admin_demarches_screen.dart` + éditeur |
| Événements : annulation motivée, suppression encadrée, historique | `20261018170000` | 30 | onglet Événements de `admin_moderation_screen.dart` |
| Annuaire : badge motivé, archivage, historique | `20261018190000` | 59 | `admin_businesses_screen.dart` |
| Campagnes de notification (remplace un écran qui n'envoyait rien) | `20261018210000` | 64 | `admin_campagnes_screen.dart` |
| Demandes de données personnelles, incidents de sécurité | `20261018230000` | 59 | `admin_securite_screen.dart` |
| Demande depuis l'application, prise en charge, garde d'effacement | `20261018250000` | 38 | écran « Mes demandes sur mes données » (app) |
| Notification du demandeur, réponse écrite, état des lieux | `20261019100000` | 33 | idem, côté panneau et application |
| Tableau de bord : « À traiter » par droit | `20261019130000` | 14 | `bloc_a_traiter.dart` |
| Réglages versionnés (Firestore) | règles `11dd6216` déployées | 30 (émulateur) | historique + retour arrière |

Le panneau a été déployé le 2026-10-19 sur `diaspo-niger-admin.web.app`
(build du HEAD `2a894ec8`).

## Trouvailles faites en route

À garder, parce qu'elles auraient été invisibles autrement :

- **L'écran « Notifications » n'envoyait rien.** Il insérait dans
  `admin_notifications`, qu'aucun déclencheur ne lisait, et annonçait « envoyée ».
- **Créer un ticket de support échouait en production** : la table n'avait pas
  les colonnes que l'application écrit, et aucun administrateur ne pouvait lire
  un ticket (aucune policy).
- **Le tableau de bord rendait 0** quand une lecture échouait : un refus de
  permission se lisait « 0 signalement ».
- **Une policy qui appelle `admin_has_permission` fait échouer la lecture
  publique** : `anon` n'a pas `EXECUTE` sur la fonction. Deux policies, pas un
  `OR` (trouvé par le banc des démarches).
- **`<>` avec une valeur nulle vaut NULL** : un `assigned_to` vide laissait
  traiter une demande qu'on n'avait pas prise.
- **Les règles Firestore du dépôt étaient identiques à la production** au
  2026-10-19 (relues à l'API) ; elles l'ont été de nouveau après le déploiement
  du jeu `11dd6216`.

## Pièges de méthode (propres à ce dépôt)

- **Appliquer UNE migration sans embarquer celles d'un autre** : `supabase db
  push` applique tout ce qui est en attente. Pour une seule :
  `supabase db query --linked -f <fichier>` puis
  `supabase migration repair --status applied <version> --linked`.
- **Deux sessions dans le même worktree** : l'index est partagé ; ne jamais
  `git add -A`, ajouter par nom de fichier. Un `git push` publie aussi les
  commits de l'autre.
- **Un préfixe de migration en double fait échouer `db push`** :
  `ls supabase/migrations | awk -F_ '{print $1}' | sort | uniq -d`.
- **`build_runner --delete-conflicting-outputs`** supprime ~130 `.g.dart` suivis
  par git : restaurer avec `git ls-files -d | xargs git checkout --`, et
  restreindre avec `--build-filter`.
- **Les gardes du dépôt attrapent de vrais défauts** : sortie visible sans pile
  (`fleche_retour_test`), réponse du pont d'authentification ignorée
  (`refus_du_pont_respecte_test`), succès annoncé seul (`echec_muet_test`).

## Décisions qui attendent quelqu'un

| Sujet | Pourquoi ce n'est pas technique |
|---|---|
| Rôles manquants (agent de support, validateur, auditeur, analyste) | tout est mappé à `contentMod`, `businessMod`, `financeMod` ou `superAdmin` ; les permissions `communications.send`, `privacy.requests.manage`, `security.incidents.manage`, `events.delete` ne sont portées que par le superAdmin |
| Délai légal affiché à l'utilisateur pour une demande de données | engagement juridique qui dépend du droit applicable ; l'échéance de 30 jours est interne |
| Approbation préalable des événements | produit : aujourd'hui un organisateur publie directement |
| Détection de doublons de fiches, normalisation de `country_code` (noms en toutes lettres) | un index unique ferait échouer des créations existantes ; chantier de données |
| 7 fiches d'annuaire douteuses (nom vide, « 200000 », ville « carte ») | décision de contenu : archiver, sans détruire |
| Seconde approbation d'un réglage critique | non bloquée techniquement |
| Changement de rôle avec double validation | passe par la Cloud Function `setAdminRole` (déploiement de fonctions à fiabiliser) |

## Limites connues, non corrigées

- Aucune notification des inscrits à l'annulation d'un événement (la chaîne push
  n'accepte qu'une liste fermée de types, à élargir avec précaution).
- Une démarche dépubliée reste affichée hors ligne jusqu'à la prochaine
  synchronisation ; la copie embarquée dans l'APK n'est mise à jour qu'à la
  livraison. L'application dit maintenant de quand date sa liste.
- Les demandes d'accès et d'effacement ne sont pas exécutées par le suivi : la
  suppression passe par le parcours de suppression de compte, avec son délai de
  grâce.
- Un envoi de campagne « créé » n'est pas « livré » : la livraison réelle se lit
  dans `net._http_response` (recette du 2026-09-15).
- Tests en échec avant ce travail et non liés à lui :
  `test/core/services/distribue_en_arriere_plan_test.dart` (2 cas).

## Reste du plan du référentiel

Responsive et accessibilité (étape 9 de l'ordre recommandé), tests de recette
sur appareils réels (voir `TESTS_APPAREIL_A_FAIRE.md`, une entrée par module),
exploitation (sauvegardes testées, objectifs de reprise : aucune sauvegarde
Supabase n'existe à ce jour), et les décisions ci-dessus.
