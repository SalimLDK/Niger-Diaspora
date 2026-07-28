# Memory Index

- [user_salim.md](user_salim.md) — Salim, dev solo diaspo_niger (Flutter/Riverpod, Firebase→Supabase) : pas d'émulateur (analyze seul), branche wip-jules partagée avec l'agent Jules, français
- [feedback_working_style.md](feedback_working_style.md) — Commit+push par étape (messages FR), franchise sur le bloqué/non-testable, ne jamais écraser le WIP (stash chirurgical), classer `git diff -w` avant de committer
- [project_audit_remediation.md](project_audit_remediation.md) — Audit sécurité messagerie diaspo_niger : findings confirmés, faux positifs, et état des corrections P0/P1/P2
- [project_e2ee_status.md](project_e2ee_status.md) — Statut E2EE : Signal câblé (1:1+groupes), clé AES globale = fallback/aperçus/localisation/background ; per-conversation keys écarté
- [project_supabase_write_auth_guard.md](project_supabase_write_auth_guard.md) — Toute écriture Supabase doit appeler ensureAuthenticated() avant l'opération (sinon RLS bloque en anon)
- [project_supabase_schema_drift.md](project_supabase_schema_drift.md) — Cause des PGRST205 (tables manquantes au distant) + méthode d'audit app-vs-remote + backend Heritage créé le 2026-06-25
- [project_feed_roadmap.md](project_feed_roadmap.md) — Feed déjà mature : roadmap priorisée engagement (P0/P1), ce qui est écarté, et notifs feed orphelines (triggers Firestore morts)
- [project_share_feature.md](project_share_feature.md) — Partage externe refait (liens /feed/:id, hôte diasponiger.web.app, external_share_count) + dettes iOS/web fallback
- [project_supabase_session_lifecycle.md](project_supabase_session_lifecycle.md) — Bridge Firebase→Supabase : 3 protections (dédup sync, hasValidSession, realtime.setAuth + timer) contre les 401 magic link et InvalidJWTToken
- [project_gifs_stickers.md](project_gifs_stickers.md) — GIFs = Tenor primaire + Giphy repli ; un GIF réutilise le transport « sticker » (pas de MessageType.gif) ; packs Supabase vides
- [project_polls_events_scope.md](project_polls_events_scope.md) — Sondages = groupes uniquement (contrainte DB), événements = groupes + DM ; compte de test à 0 groupe = sondages invisibles
- [project_pinned_banner_telegram.md](project_pinned_banner_telegram.md) — Bandeau épinglé : ligne fine Telegram toujours visible, jamais masquée au clavier ; cascade de désépinglage à la suppression
- [project_message_dedup_typing.md](project_message_dedup_typing.md) — Fix doublons/auto-écho E2EE (matcher par clientMessageId + _reconcileEcho + fenêtre 15s), « écrit… » dans la liste, cadenas retiré ; clientMessageId non propagé aux stickers/localisation
- [project_self_notes.md](project_self_notes.md) — Fonction « Mes notes » (self-chat) : détection participant unique, tuile épinglée, texte chiffré AES vers soi, brouillon de sondage (note texte)
- [project_build_gotchas.md](project_build_gotchas.md) — Build Android : compileSdk reste 36 (faux SDK android-37 supprimés) ; template l10n = app_fr.arb, parité des métadonnées @clé obligatoire sinon gen-l10n échoue en silence
- [project_supabase_over_firebase.md](project_supabase_over_firebase.md) — Direction : Supabase préféré à Firebase ; 37 fonctions HTTPS portables tout de suite, 33 triggers Firestore suivent leur donnée
- [project_feed_discussion_redesign.md](project_feed_discussion_redesign.md) — Refonte design Fil & Discussion + tours 7-28 : quasi tout l'ordre d'implémentation fait (23 commits sur branche wip-jules) ; reste = données/modèles absents (ville, stories, filtre serveur), passe modales complète, WIP user message_input

> Note : deux mémoires sécurité-sensibles (`project_coturn_vps`, `project_firebase_functions_deploy_blocked`) sont volontairement **hors dépôt** — elles restent dans le store de mémoire local de Claude.
