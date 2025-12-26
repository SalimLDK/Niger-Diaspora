# Diaspo Niger

Bienvenue sur le projet **Diaspo Niger**.

## Documentation

La documentation détaillée se trouve dans le dossier `docs/` :

1.  **[Vue d'ensemble du Projet](docs/PROJECT_OVERVIEW.md)**
    *   Architecture, Structure des dossiers, Stack technique.
2.  **[Configuration](docs/CONFIGURATION.md)**
    *   Variables d'environnement, Feature Flags, Stripe, Firebase.
3.  **[Déploiement](docs/DEPLOYMENT.md)**
    *   Génération des livrables (APK, AAB, IPA) pour la production.

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
