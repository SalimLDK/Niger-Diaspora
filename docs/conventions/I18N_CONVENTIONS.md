# Conventions d'Internationalisation (i18n) - Diaspo Niger

Ce document décrit les conventions et outils pour l'internationalisation de l'application.

## Table des matières

1. [Architecture](#architecture)
2. [Fichiers de traduction](#fichiers-de-traduction)
3. [Utilisation dans le code](#utilisation-dans-le-code)
4. [Services utilitaires](#services-utilitaires)
5. [Pluriels ICU](#pluriels-icu)
6. [Dates et nombres](#dates-et-nombres)
7. [Extensions d'enums](#extensions-denums)
8. [SnackBars localisés](#snackbars-localisés)
9. [Détection des strings hardcodées](#détection-des-strings-hardcodées)
10. [Checklist de migration](#checklist-de-migration)

---

## Architecture

```
lib/
├── l10n/
│   ├── app_fr.arb          # Traductions françaises (source)
│   ├── app_en.arb          # Traductions anglaises
│   ├── app_localizations.dart      # Généré automatiquement
│   ├── app_localizations_fr.dart   # Généré automatiquement
│   └── app_localizations_en.dart   # Généré automatiquement
├── core/
│   ├── utils/
│   │   ├── locale_helper.dart      # Helper pour les dates/locales
│   │   └── enum_extensions.dart    # Extensions d'enums localisées
│   └── services/
│       └── snackbar_service.dart   # Service SnackBar centralisé
└── scripts/
    └── check_hardcoded_strings.dart # Script de détection
```

---

## Fichiers de traduction

### Structure des fichiers ARB

Les fichiers ARB utilisent le format JSON avec des métadonnées :

```json
{
  "@@locale": "fr",

  "myKey": "Ma valeur",

  "keyWithParam": "Bonjour {name}",
  "@keyWithParam": {
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },

  "pluralKey": "{count, plural, =0{Aucun} =1{Un élément} other{{count} éléments}}",
  "@pluralKey": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

### Convention de nommage des clés

| Préfixe | Usage | Exemple |
|---------|-------|---------|
| `emptyState*` | États vides | `emptyStateNoDataTitle` |
| `transfer*` | Transferts d'argent | `transferSendMoney` |
| `business*` | Entreprises | `businessCategoryRestaurant` |
| `event*` | Événements | `eventCategoryCultural` |
| `group*` | Groupes | `groupRequestSent` |
| `call*` | Appels | `callMissed` |
| `transactionStatus*` | Statuts de transaction | `transactionStatusPending` |

### Régénération des fichiers

Après toute modification des fichiers ARB :

```bash
flutter gen-l10n
```

---

## Utilisation dans le code

### Import

```dart
import '../../l10n/app_localizations.dart';
```

### Accès aux traductions

```dart
// Dans une méthode build()
final l10n = AppLocalizations.of(context)!;

// Utilisation
Text(l10n.homeTitle)
Text(l10n.participants(5))  // Avec paramètre
```

### Extension pratique

```dart
import '../../core/utils/locale_helper.dart';

// Usage simplifié avec extension
Text(context.l10n.homeTitle)
```

---

## Services utilitaires

### LocaleHelper

Le fichier `lib/core/utils/locale_helper.dart` fournit :

```dart
// Obtenir le code locale
String locale = LocaleHelper.getLocaleCode(context);  // 'fr' ou 'en'

// Obtenir la locale pour DateFormat
String dfLocale = LocaleHelper.getDateFormatLocale(context);  // 'fr_FR' ou 'en_US'

// Formater une date
String date = LocaleHelper.formatDate(context, DateTime.now());
String fullDate = LocaleHelper.formatFullDate(context, DateTime.now());
String time = LocaleHelper.formatTime(context, DateTime.now());

// Temps relatif localisé
String ago = LocaleHelper.timeAgo(context, someDateTime);  // "Il y a 5 min"

// Extension de context
context.dateFormat('dd MMMM yyyy').format(date)
```

---

## Pluriels ICU

### Format ICU MessageFormat

```json
{
  "items": "{count, plural, =0{Aucun élément} =1{1 élément} other{{count} éléments}}"
}
```

### Syntaxe

- `=0` : Exactement zéro
- `=1` : Exactement un
- `other` : Tous les autres cas (obligatoire)
- `{count}` : Interpolation de la variable

### Exemples implémentés

```dart
// Dans le code
l10n.participants(0)  // "Aucun participant"
l10n.participants(1)  // "1 participant"
l10n.participants(5)  // "5 participants"

l10n.members(0)       // "Aucun membre"
l10n.members(1)       // "1 membre"
l10n.members(10)      // "10 membres"
```

---

## Dates et nombres

### ❌ À éviter

```dart
// Locale hardcodée
DateFormat('dd MMMM yyyy', 'fr_FR').format(date)
```

### ✅ Bonne pratique

```dart
import '../../core/utils/locale_helper.dart';

// Avec LocaleHelper
LocaleHelper.formatFullDate(context, date)

// Avec extension
context.dateFormat('dd MMMM yyyy').format(date)
```

---

## Extensions d'enums

Le fichier `lib/core/utils/enum_extensions.dart` fournit des extensions localisées pour les enums :

### TransactionStatus

```dart
import '../../core/utils/enum_extensions.dart';

final status = TransactionStatus.completed;

// Label localisé
Text(status.getLocalizedLabel(context))  // "Terminé" ou "Completed"

// Couleur
Color color = status.color;  // Colors.green

// Icône
IconData icon = status.icon;  // Icons.check_circle
```

### BusinessCategory

```dart
final category = BusinessCategory.restaurant;
Text(category.getLocalizedLabel(context))  // "Restaurant"
Icon(category.icon)  // Icons.restaurant
```

### Autres enums supportés

- `EventCategory`
- `NotificationType`
- `CallType`
- `CallStatus`

---

## SnackBars localisés

Le fichier `lib/core/services/snackbar_service.dart` centralise les SnackBars :

### Usage direct

```dart
import '../../core/services/snackbar_service.dart';

// Messages génériques
SnackBarService.showSuccess(context, l10n.success);
SnackBarService.showError(context, l10n.error);
SnackBarService.showWarning(context, l10n.warning);

// Messages pré-définis
SnackBarService.showNetworkError(context);
SnackBarService.showSelectRecipient(context);
SnackBarService.showTransferInitiated(context);
SnackBarService.showBusinessCreated(context);
```

### Extension de context

```dart
context.showSuccessSnackBar('Message de succès');
context.showErrorSnackBar('Message d\'erreur');
context.showNetworkErrorSnackBar();
```

---

## Détection des strings hardcodées

### Script de détection

```bash
dart run scripts/check_hardcoded_strings.dart
```

Ce script détecte :
- `Text('...')` avec strings littérales
- `title: Text('...')` dans AppBar
- `SnackBar(content: Text('...'))`
- `labelText: '...'`, `hintText: '...'`
- `tooltip: '...'`, `label: '...'`
- `DateFormat(..., 'fr_FR')` hardcodé

### Exemple de sortie

```
⚠️  Found 15 potential hardcoded strings:

📁 lib/features/transfers/presentation/screens/send_money_screen.dart
  Line 74: title: const Text('Envoyer de l\'argent'),
  Line 85: child: const Text('Reinitialiser'),

📁 lib/shared/widgets/empty_state_widget.dart
  Line 89: child: Text(actionLabel ?? config.actionLabel ?? 'Réessayer'),
```

---

## Checklist de migration

### Pour chaque fichier à migrer :

- [ ] Ajouter l'import `app_localizations.dart`
- [ ] Créer `final l10n = AppLocalizations.of(context)!;` dans build()
- [ ] Remplacer les `const Text('...')` par `Text(l10n.xxx)`
- [ ] Remplacer les `DateFormat(..., 'fr_FR')` par `LocaleHelper.dateFormat(context, ...)`
- [ ] Utiliser `SnackBarService` pour les SnackBars
- [ ] Utiliser `enum.getLocalizedLabel(context)` pour les labels d'enum
- [ ] Ajouter les clés manquantes dans `app_fr.arb` ET `app_en.arb`
- [ ] Exécuter `flutter gen-l10n`
- [ ] Tester en français ET en anglais

### Commandes utiles

```bash
# Régénérer les localisations
flutter gen-l10n

# Vérifier les strings hardcodées
dart run scripts/check_hardcoded_strings.dart

# Analyser le code
flutter analyze
```

---

## Ressources

- [Flutter Internationalization](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ICU MessageFormat](https://unicode-org.github.io/icu/userguide/format_parse/messages/)
- [intl package](https://pub.dev/packages/intl)

---

*Dernière mise à jour : Février 2026*
