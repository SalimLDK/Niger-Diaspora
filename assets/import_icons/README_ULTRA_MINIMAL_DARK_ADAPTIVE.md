# 🎨 Logos ND Ultra Minimal + Dark Mode + Adaptive Icons Android

## 📦 Nouveaux Logos

### 1. ND Ultra Minimal - `nd_ultra_minimal`
**Caractéristiques** :
- Police **ultra grasse** (font-weight 900)
- Fond orange dégradé
- AUCUN élément décoratif
- Juste "ND" centré
- Maximum de simplicité et impact

**Fichiers** :
- `nd_ultra_minimal.svg` - Format vectoriel
- `nd_ultra_minimal_icon.png` - 512×512px
- `nd_ultra_minimal_hd.png` - 1024×1024px

---

### 2. ND Dark Mode - `nd_dark_mode`
**Caractéristiques** :
- Fond sombre dégradé (#1A1A1A → #2D2D2D)
- Texte "ND" en dégradé orange
- Police ultra grasse
- Parfait pour les thèmes sombres

**Fichiers** :
- `nd_dark_mode.svg` - Format vectoriel
- `nd_dark_mode_icon.png` - 512×512px
- `nd_dark_mode_hd.png` - 1024×1024px

---

## 📱 Adaptive Icons Android

Les **adaptive icons** Android permettent d'avoir des icônes qui s'adaptent à différentes formes (cercle, carré arrondi, etc.) selon le launcher utilisé.

### Structure Adaptive Icon

Un adaptive icon Android est composé de 2 couches :
1. **Background** : Couche de fond (couleur ou image)
2. **Foreground** : Couche de premier plan (logo transparent)

### Fichiers Fournis

#### Version Light (Default)
- `nd_adaptive_background.svg` / `.png` - Fond orange dégradé
- `nd_adaptive_foreground.svg` / `.png` - "ND" blanc sur transparent
- `nd_adaptive_background_xxxhdpi.png` - 432×432px (haute résolution)
- `nd_adaptive_foreground_xxxhdpi.png` - 432×432px (haute résolution)

#### Version Dark
- `nd_adaptive_background_dark.svg` / `.png` - Fond sombre
- `nd_adaptive_foreground_dark.svg` / `.png` - "ND" orange sur transparent
- `nd_adaptive_background_dark_xxxhdpi.png` - 432×432px
- `nd_adaptive_foreground_dark_xxxhdpi.png` - 432×432px

---

## 🚀 Intégration Flutter - Méthode Automatique

### Option 1 : flutter_launcher_icons (Recommandé)

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  
  # Icône standard
  image_path: "assets/images/nd_ultra_minimal_icon.png"
  
  # Android adaptive icon
  adaptive_icon_background: "#E97424"  # Couleur orange
  adaptive_icon_foreground: "assets/images/nd_adaptive_foreground_xxxhdpi.png"
  
  # iOS
  remove_alpha_ios: true
```

Puis exécuter :
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

---

## 🔧 Intégration Android Native - Méthode Manuelle

### Étape 1 : Préparer les Fichiers

Créer la structure de dossiers dans `android/app/src/main/res/` :

```
res/
├── mipmap-anydpi-v26/
│   ├── ic_launcher.xml
│   └── ic_launcher_round.xml
├── mipmap-mdpi/
│   ├── ic_launcher_background.png
│   └── ic_launcher_foreground.png
├── mipmap-hdpi/
│   ├── ic_launcher_background.png
│   └── ic_launcher_foreground.png
├── mipmap-xhdpi/
│   ├── ic_launcher_background.png
│   └── ic_launcher_foreground.png
├── mipmap-xxhdpi/
│   ├── ic_launcher_background.png
│   └── ic_launcher_foreground.png
└── mipmap-xxxhdpi/
    ├── ic_launcher_background.png
    └── ic_launcher_foreground.png
```

### Étape 2 : Générer les Différentes Résolutions

Tu peux utiliser les fichiers PNG fournis (`nd_adaptive_foreground_xxxhdpi.png` et `nd_adaptive_background_xxxhdpi.png`) et les redimensionner :

| Densité | Taille | Multiplicateur |
|---------|--------|----------------|
| mdpi | 108×108 | 1x |
| hdpi | 162×162 | 1.5x |
| xhdpi | 216×216 | 2x |
| xxhdpi | 324×324 | 3x |
| xxxhdpi | 432×432 | 4x ✅ (fourni) |

### Étape 3 : Créer les XML

**`mipmap-anydpi-v26/ic_launcher.xml`** :
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

**`mipmap-anydpi-v26/ic_launcher_round.xml`** :
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

### Étape 4 : Alternative - Utiliser une Couleur Solide pour le Background

Si tu veux juste la couleur orange sans dégradé (plus léger), crée :

**`res/values/ic_launcher_background.xml`** :
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#E97424</color>
</resources>
```

Puis modifie `ic_launcher.xml` :
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

---

## 🌓 Support du Dark Mode dans l'App

### Détecter le Thème Système

```dart
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Niger Diaspora',
      
      // Thème light
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFFE97424),
        scaffoldBackgroundColor: Colors.white,
      ),
      
      // Thème dark
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFFE97424),
        scaffoldBackgroundColor: Color(0xFF1A1A1A),
      ),
      
      // Suivre le système
      themeMode: ThemeMode.system,
      
      home: HomePage(),
    );
  }
}
```

### Afficher le Logo Adaptatif selon le Thème

```dart
class AdaptiveLogo extends StatelessWidget {
  final double size;
  
  const AdaptiveLogo({Key? key, this.size = 80}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Détecter si on est en dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Image.asset(
      isDarkMode 
          ? 'assets/images/nd_dark_mode_icon.png'
          : 'assets/images/nd_ultra_minimal_icon.png',
      width: size,
      height: size,
    );
  }
}

// Usage
AdaptiveLogo(size: 100)
```

### Splash Screen Adaptatif

```dart
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode 
          ? Color(0xFF1A1A1A) 
          : Color(0xFFE97424),
      body: Center(
        child: AdaptiveLogo(size: 150),
      ),
    );
  }
}
```

---

## 📊 Script de Redimensionnement (Optionnel)

Si tu veux générer toutes les tailles à partir des fichiers xxxhdpi :

```python
#!/usr/bin/env python3
import os
from PIL import Image

# Définir les tailles
sizes = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432
}

# Fichiers sources
source_files = [
    'nd_adaptive_foreground_xxxhdpi.png',
    'nd_adaptive_background_xxxhdpi.png'
]

# Dossier de sortie
output_dir = 'android_adaptive_icons'
os.makedirs(output_dir, exist_ok=True)

for source_file in source_files:
    # Déterminer le nom de base
    if 'foreground' in source_file:
        base_name = 'ic_launcher_foreground'
    else:
        base_name = 'ic_launcher_background'
    
    # Ouvrir l'image source
    img = Image.open(source_file)
    
    for density, size in sizes.items():
        # Créer le dossier
        density_dir = os.path.join(output_dir, f'mipmap-{density}')
        os.makedirs(density_dir, exist_ok=True)
        
        # Redimensionner et sauvegarder
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        output_path = os.path.join(density_dir, f'{base_name}.png')
        resized.save(output_path, 'PNG')
        
        print(f'✓ Created: {output_path} ({size}x{size})')

print('\n✅ All adaptive icons generated!')
```

Sauvegarde ce script comme `generate_adaptive_icons.py` et exécute :
```bash
pip install Pillow
python3 generate_adaptive_icons.py
```

---

## 🎨 Comparaison des Versions

| Version | Style | Background | Foreground | Usage |
|---------|-------|------------|------------|-------|
| **Ultra Minimal** | Très épuré | Orange | ND blanc | Défaut, icône app |
| **Dark Mode** | Adapté au sombre | Noir/gris | ND orange | Thème sombre |
| **Adaptive Light** | Standard Android | Orange | ND blanc | Android launcher |
| **Adaptive Dark** | Android sombre | Noir/gris | ND orange | Android 12+ dark |

---

## 📏 Spécifications Techniques

### Dimensions Adaptive Icon Android
- **Safe zone** : Cercle de 66dp de diamètre (centré)
- **Canvas total** : 108×108dp
- Le système peut rogner jusqu'à 33% des bords selon la forme du launcher

### Formats de Fichiers
- **SVG** : Vectoriel, parfait pour tout usage
- **PNG** : Raster, optimal pour les icônes Android
- **Transparence** : Alpha channel activé pour les foregrounds

---

## ✅ Checklist d'Intégration

- [ ] Copier les fichiers dans `assets/images/`
- [ ] Configurer `pubspec.yaml` avec flutter_launcher_icons
- [ ] Exécuter `flutter pub run flutter_launcher_icons`
- [ ] Tester sur émulateur Android (différents launchers)
- [ ] Tester sur appareil réel (light et dark mode)
- [ ] Vérifier l'icône dans les paramètres Android
- [ ] Tester avec différentes formes (cercle, carré arrondi, etc.)

---

## 💡 Conseils

1. **Adaptive Icons** : Garde toujours les éléments importants dans le cercle central (safe zone de 66dp)
2. **Dark Mode** : Teste toujours sur un vrai device avec OLED pour voir le rendu final
3. **Foreground** : Assure-toi qu'il a de la transparence, pas de fond blanc
4. **Background** : Peut être une couleur solide (#E97424) ou une image (dégradé)

---

## 🔗 Ressources

- [Guide officiel Android Adaptive Icons](https://developer.android.com/guide/practices/ui_guidelines/icon_design_adaptive)
- [flutter_launcher_icons sur pub.dev](https://pub.dev/packages/flutter_launcher_icons)
- [Material Design Icon Guidelines](https://material.io/design/iconography/product-icons.html)

---

**Besoin d'aide ?** Demande si tu veux d'autres variantes ou ajustements !
