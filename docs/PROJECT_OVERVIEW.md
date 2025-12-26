# Vue d'ensemble du Projet - Diaspo Niger

## 1. Description
**Diaspo Niger** est une application mobile destinée à la diaspora nigérienne. Elle vise à connecter les membres de la communauté, faciliter les transferts d'argent, l'organisation d'événements et le partage d'informations.

## 2. Architecture Technique

Le projet suit une architecture propre (**Clean Architecture**) modulaire, organisée par fonctionnalités (`Package-by-Feature`).

### Structure des Dossiers (`lib/`)

- **`core/`** : Composants partagés et utilitaires.
  - `constants/` : Configurations (AppConfig), couleurs, styles.
  - `services/` : Services globaux (Feature Flags, etc.).
  - `utils/` : Fonctions utilitaires.
- **`features/`** : Fonctionnalités principales de l'application. Chaque feature contient généralement :
  - `data/` : Sources de données (API, Firebase) et Repositories.
  - `domain/` : Entités et Cas d'utilisation.
  - `presentation/` : Écrans, Widgets et Gestion d'état (Providers).

### Stack Technologique

- **Framework** : Flutter (SDK ^3.7.0)
- **Langage** : Dart
- **Gestion d'état** : Riverpod (`flutter_riverpod`, `riverpod_annotation`)
- **Backend / BaaS** : Firebase
  - Auth (Authentification)
  - Firestore (Base de données NoSQL)
  - Realtime Database (Messagerie instantanée)
  - Storage (Stockage de fichiers)
  - Cloud Functions (Logique serveur)
  - Remote Config & App Check
- **Navigation** : GoRouter
- **Paiements** : Stripe (`flutter_stripe`)
- **Cartographie** : Google Maps
- **Stockage Local** : Hive, Shared Preferences

## 3. Fonctionnalités Clés

*   **Authentification** : Connexion via Email/Mot de passe, Google.
*   **Événements** : Création, gestion et participation à des événements communautaires.
*   **Messagerie** : Chat en temps réel (1-to-1 et groupes) avec partage de médias.
*   **Transferts** : Simulation et initation de transferts d'argent (via Stripe).
*   **Réseau** : Gestion de profil, ajout d'amis, recherche de membres.
*   **Nouveautés** : Fil d'actualité ou annonces importantes.

## 4. conventions de Code

- **Linter** : `flutter_lints` est utilisé pour assurer la qualité du code.
- **Génération de Code** : Utilisation de `build_runner` pour Freezed, Riverpod Generator et JSON Serializable.
  - Commande de génération : `dart run build_runner build --delete-conflicting-outputs`
