# Guide : Remplacer le Thème par Défaut (Vert Principal)

Ce guide explique comment modifier le thème par défaut (`lightTheme`) pour que la couleur **Verte** devienne la couleur principale (au lieu de l'Orange), et l'Orange devienne la couleur secondaire.

## 1. Comprendre les Couleurs
- `AppColors.primary` : Orange (Reste défini comme tel dans `app_colors.dart`)
- `AppColors.secondary` : Vert (Reste défini comme tel dans `app_colors.dart`)

Nous allons inverser leur utilisation dans `AppTheme`.

## 2. Modifier `lightTheme` dans `AppTheme`
Ouvrez le fichier `lib/core/theme/app_theme.dart` et modifiez le getter `lightTheme`.

### Changements à effectuer :
Remplacez les assignations de `primary` par les couleurs secondaires, et vice-versa.

```dart
// Dans lib/core/theme/app_theme.dart

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ============================================
      // COLOR SCHEME - INVERSION (VERT PRINCIPAL)
      // ============================================
      colorScheme: const ColorScheme.light(
        // Le PRIMARY devient les couleurs du range SECONDAIRE (Vert)
        primary: AppColors.secondary,
        onPrimary: AppColors.textInverse,
        primaryContainer: AppColors.secondaryLighter,
        onPrimaryContainer: AppColors.secondaryDark,

        // Le SECONDARY devient les couleurs du range PRIMAIRE (Orange)
        secondary: AppColors.primary,
        onSecondary: AppColors.textInverse,
        secondaryContainer: AppColors.primaryLighter,
        onSecondaryContainer: AppColors.primaryDark,
        
        // Le reste ne change pas
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        error: AppColors.error,
        onError: AppColors.textInverse,
        outline: AppColors.border,
        outlineVariant: AppColors.borderStrong,
      ),

      // ... (Le reste de la configuration)

      // ============================================
      // COMPOSANTS SPÉCIFIQUES
      // ============================================
      
      // Mettez à jour les composants qui référencent explicitement AppColors.primary
      // pour qu'ils utilisent AppColors.secondary (ou primary de la themeData)
      
      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary, // Utiliser le Vert
          // ou mieux :
          // backgroundColor: AppColors.secondary, 
          // ...
        ),
      ),

      // Input Decoration (Focus border)
      inputDecorationTheme: InputDecorationTheme(
        // ...
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMD,
          borderSide: const BorderSide(
            color: AppColors.secondary, // Focus vert
            width: AppSpacing.borderWidthMedium,
          ),
        ),
      ),
      
      // TabBar
       tabBarTheme: TabBarTheme(
        labelColor: AppColors.secondary, // Label vert
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppColors.secondary, // Ligne verte
            width: 2,
          ),
        ),
         // ...
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary; // Switch on vert
          }
          return AppColors.textTertiary;
        }),
         // ...
      ),
      
      // Checkbox
      checkboxTheme: CheckboxThemeData(
         fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary; // Checkbox vert
          }
          return Colors.transparent;
        }),
        // ...
      ),
      
      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary; // Radio vert
          }
          return AppColors.textTertiary;
        }),
      ),
    );
  }
```

## 3. prendre en compte votre demande :

Thème par Défaut (Vert) : Le getter lightTheme deviendra le thème vert.
Ancien Thème (Orange) : L'actuel lightTheme sera renommé orangeTheme pour rester accessible.

## 4. Autres Ajustements (Optionnel)
Si vous avez des boutons spécifiques ou des styles définis en dehors du thème qui utilisent `AppColors.primary` en dur, vous devrez peut-être les rechercher (Ctrl+Shift+F `AppColors.primary`) et les remplacer par `AppColors.secondary` ou utiliser `Theme.of(context).primaryColor`.
