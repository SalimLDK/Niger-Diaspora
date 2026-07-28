---
name: user_salim
description: "Qui est Salim (dev solo diaspo_niger) + contraintes dures de l'environnement — pas d'émulateur, branche partagée avec l'agent Jules, français"
metadata: 
  node_type: memory
  type: user
  originSessionId: 583381e0-f82b-4106-8cae-5ae186d21804
  modified: 2026-07-28T17:36:59.198Z
---

**Salim** — développeur solo de **diaspo_niger**, une app Flutter pour la diaspora nigérienne (Riverpod + go_router + architecture par feature ; backend en migration Firebase → Supabase, cf [[project_supabase_over_firebase]]). Email : salimlaoualidankobo@gmail.com. Travaille sous **Windows** (PowerShell + Git Bash).

Contraintes dures à connaître avant de proposer quoi que ce soit :

- **Aucun émulateur / device Android disponible** côté agent : on ne peut PAS tester à l'exécution. La seule vérification possible est `flutter analyze`. Les changements de gestes / layout / navigation (ex. sheets, steppers custom, DraggableScrollableSheet) sont à signaler comme « à valider à la main sur device ». (`flutter test` ne tourne pas non plus — disque quasi plein, cf [[project_audit_remediation]].)
- **Branche de travail = `wip-jules-*`**, éditée EN PARALLÈLE par un agent autonome « Jules ». Toujours **relire l'état courant d'un fichier avant de l'éditer** ; des changements non-siens apparaissent régulièrement dans l'arbre (cf [[project_feed_roadmap]] et la refonte 2026-07-28).
- **Français par défaut** : messages de commit, commentaires de code et l10n en français d'abord (template `app_fr.arb`, cf [[project_build_gotchas]]), app bilingue FR/EN.

Préférences de collaboration : voir [[feedback_working_style]].
