#!/usr/bin/env python3
"""
Script pour générer toutes les résolutions d'adaptive icons Android
à partir des fichiers xxxhdpi (432x432)
"""

import os
from PIL import Image

# Définir les tailles pour chaque densité
SIZES = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432
}

# Fichiers sources (dans le répertoire courant)
SOURCE_FILES = {
    'foreground': 'nd_adaptive_foreground_xxxhdpi.png',
    'background': 'nd_adaptive_background_xxxhdpi.png',
    'foreground_dark': 'nd_adaptive_foreground_dark_xxxhdpi.png',
    'background_dark': 'nd_adaptive_background_dark_xxxhdpi.png',
}

# Dossier de sortie
OUTPUT_DIR = 'android_adaptive_icons'

def generate_adaptive_icons():
    """Génère toutes les résolutions d'adaptive icons"""
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"📁 Creating output directory: {OUTPUT_DIR}\n")
    
    total_files = 0
    
    for file_type, source_file in SOURCE_FILES.items():
        # Vérifier si le fichier source existe
        if not os.path.exists(source_file):
            print(f"⚠️  Warning: {source_file} not found, skipping...")
            continue
        
        # Déterminer le nom de fichier de sortie
        if 'foreground' in file_type:
            output_name = 'ic_launcher_foreground'
            if 'dark' in file_type:
                output_name += '_dark'
        else:
            output_name = 'ic_launcher_background'
            if 'dark' in file_type:
                output_name += '_dark'
        
        print(f"🎨 Processing: {source_file}")
        
        # Ouvrir l'image source
        img = Image.open(source_file)
        
        for density, size in SIZES.items():
            # Créer le dossier pour cette densité
            density_dir = os.path.join(OUTPUT_DIR, f'mipmap-{density}')
            os.makedirs(density_dir, exist_ok=True)
            
            # Redimensionner l'image
            resized = img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Sauvegarder
            output_path = os.path.join(density_dir, f'{output_name}.png')
            resized.save(output_path, 'PNG', optimize=True)
            
            total_files += 1
            print(f"  ✓ {density:8s} → {output_path} ({size}×{size}px)")
        
        print()
    
    print(f"\n✅ Successfully generated {total_files} files!")
    print(f"📦 Output directory: {OUTPUT_DIR}/")
    print(f"\nNext steps:")
    print(f"1. Copy the mipmap-* folders to android/app/src/main/res/")
    print(f"2. Create ic_launcher.xml in mipmap-anydpi-v26/")
    print(f"3. Rebuild your Android app")

def create_xml_templates():
    """Crée les templates XML pour les adaptive icons"""
    
    xml_dir = os.path.join(OUTPUT_DIR, 'mipmap-anydpi-v26')
    os.makedirs(xml_dir, exist_ok=True)
    
    # ic_launcher.xml
    ic_launcher_xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
    
    # ic_launcher_round.xml
    ic_launcher_round_xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
    
    with open(os.path.join(xml_dir, 'ic_launcher.xml'), 'w') as f:
        f.write(ic_launcher_xml)
    
    with open(os.path.join(xml_dir, 'ic_launcher_round.xml'), 'w') as f:
        f.write(ic_launcher_round_xml)
    
    print(f"\n📄 Created XML templates in {xml_dir}/")

if __name__ == '__main__':
    print("🚀 Niger Diaspora - Android Adaptive Icon Generator\n")
    print("=" * 60)
    
    try:
        generate_adaptive_icons()
        create_xml_templates()
        
        print("\n" + "=" * 60)
        print("🎉 Done! Your adaptive icons are ready.")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
