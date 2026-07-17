# Diaspo Niger

Bienvenue sur le projet **Diaspo Niger**.

## Documentation

La documentation est organisée dans le dossier `docs/` — voir le **[sommaire complet](docs/README.md)**.

Points d'entrée principaux :

1.  **[Vue d'ensemble du Projet](docs/PROJECT_OVERVIEW.md)**
    *   Architecture, Structure des dossiers, Stack technique.
2.  **[Configuration](docs/configuration/CONFIGURATION.md)**
    *   Variables d'environnement, Feature Flags, Stripe, Firebase.
3.  **[Déploiement](docs/deploiement/DEPLOYMENT.md)**
    *   Génération des livrables (APK, AAB, IPA) pour la production.

Les documents historiques (audits remédiés, plans exécutés) sont dans [docs/archive/](docs/archive/README.md).

## Démarrage Rapide

### Pré-requis
-   Flutter SDK installé
-   Projet Firebase configuré (via `flutterfire configure`)

### Installation

```bash
flutter pub get
```

### Lancement (Développement)

```bash
flutter run
```

### Génération de code (Riverpod / Freezed)

Si vous modifiez des modèles ou des providers annotés :

```bash
dart run build_runner build --delete-conflicting-outputs
# Ou en mode watch pour le développement continu
dart run build_runner watch --delete-conflicting-outputs
```
