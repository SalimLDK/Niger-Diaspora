# Directive : Connexion des intervalles de rafraîchissement à la configuration admin

## Contexte

Les écrans `/map` et `/home` utilisent actuellement des intervalles de rafraîchissement **hardcodés**.
Ces valeurs devraient être configurables par l'admin via Firestore.

---

## État actuel

### Valeurs hardcodées

| Écran | Variable | Valeur | Description |
|-------|----------|--------|-------------|
| `/map` | `_membersRefreshIntervalSeconds` | 45s | Rafraîchissement liste membres |
| `/map` | `_distanceFilterMeters` | 50m | Seuil de déplacement pour mise à jour position |
| `/map` | `_uiRefreshIntervalSeconds` | 10s | Rafraîchissement affichage temps relatif |
| `/home` | `_nearbyRefreshIntervalSeconds` | 60s | Rafraîchissement liste membres |
| `/home` | `_uiRefreshIntervalSeconds` | 10s | Rafraîchissement affichage temps relatif |

### Configuration admin existante

Fichier : `lib/features/admin/domain/entities/app_settings_entity.dart`

```dart
@freezed
class SystemIntervalsEntity with _$SystemIntervalsEntity {
  const factory SystemIntervalsEntity({
    @Default(5) int locationUpdateMinutes,      // Background service
    @Default(10) int heartbeatMinutes,          // Statut en ligne
    @Default(60) int cacheMinutes,
    @Default(60) int remoteConfigFetchMinutes,
    @Default(3) int typingIndicatorSeconds,
  }) = _SystemIntervalsEntity;
}
```

---

## À implémenter

### 1. Ajouter les nouveaux champs à `SystemIntervalsEntity`

```dart
@freezed
class SystemIntervalsEntity with _$SystemIntervalsEntity {
  const factory SystemIntervalsEntity({
    // Existants
    @Default(5) int locationUpdateMinutes,
    @Default(10) int heartbeatMinutes,
    @Default(60) int cacheMinutes,
    @Default(60) int remoteConfigFetchMinutes,
    @Default(3) int typingIndicatorSeconds,

    // NOUVEAUX - À ajouter
    @Default(45) int mapMembersRefreshSeconds,      // Rafraîchissement membres sur /map
    @Default(60) int homeMembersRefreshSeconds,     // Rafraîchissement membres sur /home
    @Default(10) int uiRefreshSeconds,              // Rafraîchissement affichage temps
    @Default(50) int positionDistanceFilterMeters,  // Seuil de déplacement GPS
  }) = _SystemIntervalsEntity;
}
```

### 2. Mettre à jour le model

Fichier : `lib/features/admin/data/models/app_settings_model.dart`

Ajouter les champs correspondants dans `SystemIntervalsModel` :

```dart
@freezed
class SystemIntervalsModel with _$SystemIntervalsModel {
  const factory SystemIntervalsModel({
    // ... existants ...
    @Default(45) int mapMembersRefreshSeconds,
    @Default(60) int homeMembersRefreshSeconds,
    @Default(10) int uiRefreshSeconds,
    @Default(50) int positionDistanceFilterMeters,
  }) = _SystemIntervalsModel;
}
```

### 3. Ajouter les providers de convenance

Fichier : `lib/features/admin/presentation/providers/app_settings_provider.dart`

```dart
/// Provider pour l'intervalle de rafraîchissement des membres sur /map
@riverpod
int mapMembersRefreshSeconds(Ref ref) {
  return ref.watch(systemIntervalsProvider).mapMembersRefreshSeconds;
}

/// Provider pour l'intervalle de rafraîchissement des membres sur /home
@riverpod
int homeMembersRefreshSeconds(Ref ref) {
  return ref.watch(systemIntervalsProvider).homeMembersRefreshSeconds;
}

/// Provider pour l'intervalle de rafraîchissement UI
@riverpod
int uiRefreshSeconds(Ref ref) {
  return ref.watch(systemIntervalsProvider).uiRefreshSeconds;
}

/// Provider pour le seuil de déplacement GPS
@riverpod
int positionDistanceFilterMeters(Ref ref) {
  return ref.watch(systemIntervalsProvider).positionDistanceFilterMeters;
}
```

### 4. Modifier `/map` pour utiliser les providers

Fichier : `lib/features/map/presentation/screens/map_screen.dart`

```dart
// AVANT (hardcodé)
static const int _membersRefreshIntervalSeconds = 45;
static const int _distanceFilterMeters = 50;
static const int _uiRefreshIntervalSeconds = 10;

// APRÈS (depuis provider)
int get _membersRefreshIntervalSeconds =>
    ref.read(mapMembersRefreshSecondsProvider);
int get _distanceFilterMeters =>
    ref.read(positionDistanceFilterMetersProvider);
int get _uiRefreshIntervalSeconds =>
    ref.read(uiRefreshSecondsProvider);
```

**Note** : Utiliser `ref.read()` car ces valeurs sont lues au démarrage des timers, pas à chaque rebuild.

### 5. Modifier `/home` pour utiliser les providers

Fichier : `lib/features/home/presentation/screens/home_screen.dart`

```dart
// AVANT (hardcodé)
static const int _nearbyRefreshIntervalSeconds = 60;
static const int _uiRefreshIntervalSeconds = 10;

// APRÈS (depuis provider)
int get _nearbyRefreshIntervalSeconds =>
    ref.read(homeMembersRefreshSecondsProvider);
int get _uiRefreshIntervalSeconds =>
    ref.read(uiRefreshSecondsProvider);
```

### 6. Ajouter les contrôles dans l'écran admin

Fichier : `lib/features/admin/presentation/screens/admin_settings_screen.dart`

Dans la section "Intervalles système", ajouter :

```dart
// Rafraîchissement carte
_buildIntervalField(
  label: 'Rafraîchissement membres (carte)',
  value: intervals.mapMembersRefreshSeconds,
  suffix: 'secondes',
  onChanged: (value) => _updateMapMembersRefresh(value),
),

// Rafraîchissement accueil
_buildIntervalField(
  label: 'Rafraîchissement membres (accueil)',
  value: intervals.homeMembersRefreshSeconds,
  suffix: 'secondes',
  onChanged: (value) => _updateHomeMembersRefresh(value),
),

// Rafraîchissement UI
_buildIntervalField(
  label: 'Rafraîchissement affichage temps',
  value: intervals.uiRefreshSeconds,
  suffix: 'secondes',
  onChanged: (value) => _updateUiRefresh(value),
),

// Seuil GPS
_buildIntervalField(
  label: 'Seuil déplacement GPS',
  value: intervals.positionDistanceFilterMeters,
  suffix: 'mètres',
  onChanged: (value) => _updateDistanceFilter(value),
),
```

---

## Régénération des fichiers

Après modification des entités/models freezed :

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Valeurs recommandées

| Paramètre | Min | Recommandé | Max | Impact batterie |
|-----------|-----|------------|-----|-----------------|
| `mapMembersRefreshSeconds` | 30 | 45 | 120 | Moyen |
| `homeMembersRefreshSeconds` | 30 | 60 | 180 | Faible |
| `uiRefreshSeconds` | 5 | 10 | 30 | Très faible |
| `positionDistanceFilterMeters` | 20 | 50 | 200 | Élevé (si bas) |

---

## Tests à effectuer

1. [ ] Modifier les intervalles dans l'admin
2. [ ] Vérifier que `/map` utilise les nouvelles valeurs au prochain lancement
3. [ ] Vérifier que `/home` utilise les nouvelles valeurs au prochain lancement
4. [ ] Tester avec des valeurs extrêmes (min/max)
5. [ ] Vérifier la consommation batterie avec différentes configurations

---

## Priorité

**Moyenne** - Les valeurs hardcodées actuelles fonctionnent correctement.
L'implémentation peut être faite lors d'une prochaine itération.
