# Documentation — Diaspo Niger

Sommaire de la documentation du projet. Les documents historiques (audits terminés, plans exécutés, rapports de tâches ponctuelles) sont conservés dans [`archive/`](archive/README.md).

## Vue d'ensemble

- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) — Architecture, structure des dossiers, stack technique.

## Architecture

- [ADR-messaging-source-of-truth.md](architecture/ADR-messaging-source-of-truth.md) — **ADR (2026-07-15)** : Supabase = source de vérité de la messagerie, rôle résiduel de Firebase RTDB.
- [CALL_FLOW.md](architecture/CALL_FLOW.md) — Flux complet des appels audio/vidéo (WebRTC, signaling, coturn).
- [API_INTERNE.md](architecture/API_INTERNE.md) — Documentation des services et APIs internes. ⚠️ **Vérifié le 2026-07-25** : la section Messages est confirmée périmée (aucune mention de Supabase, décrit un `MessageRemoteDataSource` Firestore/RTDB obsolète) — bandeau ajouté dans le fichier. Le reste (Auth, Profile, autres features encore sur Firebase) n'a pas été vérifié.
- [SHARED_COMPONENTS.md](architecture/SHARED_COMPONENTS.md) — Catalogue des widgets réutilisables (`lib/shared/widgets/`).

## Configuration

- [CONFIGURATION.md](configuration/CONFIGURATION.md) — Guide unique de configuration : `.env`/AppConfig, Firebase, Supabase, Stripe, Cloud Functions, checklist pré-déploiement.
- [PARTNER_API_CONFIGURATION.md](configuration/PARTNER_API_CONFIGURATION.md) — APIs partenaires de paiement (Mynita, Wave, Visa Direct, Mastercard Send).
- [OAUTH_SECURITY_SETUP.md](configuration/OAUTH_SECURITY_SETUP.md) — Sécurisation des flux OAuth (Google Cloud Console).
- [APP_LINKS_SETUP.md](configuration/APP_LINKS_SETUP.md) — App Links Android / Universal Links iOS (liens profonds).
- [IOS_CONFIGURATION.md](configuration/IOS_CONFIGURATION.md) — Configuration iOS complète (Info.plist, entitlements, capacités, App Store).

## Déploiement

- [DEPLOYMENT.md](deploiement/DEPLOYMENT.md) — Guide unique de mise en production : tests, signature/builds Android & iOS, backend Firebase, Play Store, monitoring, checklist, dépannage.
- [ROLLBACK_AND_DATA.md](deploiement/ROLLBACK_AND_DATA.md) — Stratégie de rollback et données personnelles (RGPD).

## Notifications

- [NOTIFICATIONS_SETUP.md](notifications/NOTIFICATIONS_SETUP.md) — Configuration des notifications push (réponse directe, marquer comme lu).
- [PUSH_NOTIFICATIONS_GUIDE.md](notifications/PUSH_NOTIFICATIONS_GUIDE.md) — Guide complet : types, canaux Android, modes d'affichage.
- [PUSH_NOTIFICATIONS_REFERENCE.md](notifications/PUSH_NOTIFICATIONS_REFERENCE.md) — Tableau récapitulatif de toutes les notifications (canal, priorité, triggers).
- [PUSH_NOTIFICATIONS_MAQUETTES.md](notifications/PUSH_NOTIFICATIONS_MAQUETTES.md) — Maquettes détaillées par type de notification.

## Conventions

- [I18N_CONVENTIONS.md](conventions/I18N_CONVENTIONS.md) — Conventions d'internationalisation (fichiers `.arb`, nommage des clés, outils).

## Ops / Infrastructure

- [COTURN_VPS_SETUP.md](ops/COTURN_VPS_SETUP.md) — Installation coturn (TURN/STUN) sur VPS Hostinger avec TLS (`turn.diasponiger.com`).
- [vps_hardening.sh](ops/vps_hardening.sh) — Script de durcissement du VPS (à exécuter lors d'un rebuild).

## Légal

- [legal/](legal/README.md) — CGU, politique de confidentialité, conformité RGPD/paiements, structure juridique.

## Releases

Les notes de release et fiches Play Store sont archivées avec leurs binaires dans [`releases/`](../releases/) (ex. `releases/1.2.0+14/`).
