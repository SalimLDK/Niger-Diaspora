# 🚀 Guide de Production - Diaspo Niger

## Table des Matières
1. [Tests & Validation](#1-tests--validation-locale)
2. [Configuration Android](#2-configuration-android)
3. [Build de Production](#3-build-de-production)
4. [Firebase & Backend](#4-firebase--backend)
5. [Google Play Store - Détails Complets](#5-google-play-store---guide-complet)
6. [Monitoring Post-Production](#6-monitoring-post-production)
7. [Checklist Finale](#7-checklist-finale)

---

## 1. Tests & Validation Locale

### Vérification du Code
```bash
# Vérifier qu'il n'y a pas d'erreurs de lint
flutter analyze

# Nettoyer le projet
flutter clean
flutter pub get

# Générer les fichiers Freezed
dart run build_runner build --delete-conflicting-outputs

# Lancer les tests unitaires
flutter test

# Tester en mode release sur votre appareil
flutter run --release
```

### Points à Vérifier
- [ ] Aucune erreur dans `flutter analyze`
- [ ] L'application démarre sans crash
- [ ] Toutes les fonctionnalités principales marchent
- [ ] Les notifications fonctionnent
- [ ] Les messages s'affichent correctement
- [ ] Le fond d'écran personnalisable fonctionne
- [ ] Les transferts d'argent marchent

---

## 2. Configuration Android

### A. Versioning dans `pubspec.yaml`

Ouvrir `pubspec.yaml` et mettre à jour :
```yaml
version: 1.0.0+1
# format: VERSION_NAME+VERSION_CODE
# Exemple pour la prochaine mise à jour: 1.0.1+2
```

### B. Générer le Keystore (PREMIÈRE FOIS SEULEMENT)

⚠️ **IMPORTANT : Gardez ce fichier en sécurité ! Si vous le perdez, vous ne pourrez plus mettre à jour votre app !**

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Questions qui seront posées :**
- Password : Choisissez un mot de passe fort (NOTEZ-LE !)
- Nom et prénom : Votre nom ou nom de l'entreprise
- Unité organisationnelle : Votre département/équipe
- Organisation : Nom de votre organisation
- Ville, État, Code pays : Vos informations

**Après génération :**
1. Déplacer `upload-keystore.jks` vers `android/app/`
2. Ne JAMAIS commiter ce fichier sur Git
3. Faire une copie de sauvegarde dans un endroit sûr

### C. Créer `android/key.properties`

Créer le fichier `android/key.properties` avec :
```properties
storePassword=VOTRE_MOT_DE_PASSE
keyPassword=VOTRE_MOT_DE_PASSE
keyAlias=upload
storeFile=upload-keystore.jks
```

⚠️ **Ajouter à `.gitignore` :**
```
android/key.properties
android/app/upload-keystore.jks
```

### D. Configurer `android/app/build.gradle`

Vérifier que ces configurations sont présentes :

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

---

## 3. Build de Production

### A. Build AAB (Pour Play Store)
```bash
flutter build appbundle --release
```
📁 **Fichier généré :** `build/app/outputs/bundle/release/app-release.aab`

### B. Build APK (Pour distribution directe)
```bash
flutter build apk --release
```
📁 **Fichier généré :** `build/app/outputs/flutter-apk/app-release.apk`

### C. Tester le Build Release
```bash
flutter install --release
```

---

## 4. Firebase & Backend

### A. Vérifier les Règles Firestore

**Fichier : `firestore.rules`**
- ✅ Les règles sont sécurisées (pas de `allow read, write: if true;`)
- ✅ Toutes les collections ont des règles définies

### B. Déployer les Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

**Vérifier dans la console Firebase :**
- Toutes les fonctions sont déployées
- Aucune erreur dans les logs

### C. Déployer les Règles de Sécurité

```bash
# Règles Firestore
firebase deploy --only firestore:rules

# Règles Storage
firebase deploy --only storage:rules
```

---

## 5. Google Play Store - Guide Complet

### 🌐 Accès Console
**URL :** https://play.google.com/console

### A. Créer l'Application

1. **Console Play** → **Toutes les applications** → **Créer une application**
2. Remplir :
   - **Nom de l'application :** Diaspo Niger
   - **Langue par défaut :** Français (France)
   - **Type :** Application
   - **Gratuite ou payante :** Gratuite

---

### B. Fiche de la Boutique

#### 📝 **Détails de l'Application**

**Nom de l'application :**
```
Diaspo Niger
```

**Description courte** (80 caractères max) :
```
Connectez-vous avec la diaspora nigérienne partout dans le monde
```

**Description complète** (4000 caractères max) :
```
🌍 Rejoignez la Diaspora Nigérienne

Diaspo Niger est LA plateforme qui connecte tous les Nigériens à travers le monde. Que vous soyez à Paris, New York, Abidjan ou Niamey, restez en contact avec votre communauté.

✨ FONCTIONNALITÉS PRINCIPALES

📱 MESSAGERIE INSTANTANÉE
• Messages privés et groupes
• Partage de photos, vidéos et fichiers
• Messages vocaux
• Notifications en temps réel
• Fond d'écran personnalisable pour vos conversations

🗺️ CARTE DE LA DIASPORA
• Découvrez les Nigériens près de chez vous
• Notifications de proximité
• Filtres par région et présence

👥 GROUPES & COMMUNAUTÉS
• Créez ou rejoignez des groupes thématiques
• Groupes publics et privés
• Messages système pour notifications importantes
• Gestion avancée des membres

💸 TRANSFERTS D'ARGENT
• Envoyez de l'argent en toute sécurité
• Gestion des destinataires
• Historique des transactions
• Support multi-devises (FCFA, EUR, USD)

📅 ÉVÉNEMENTS
• Créez et découvrez les événements de la communauté
• Système de participation
• Rappels automatiques

🏪 MARKETPLACE
• Achetez et vendez entre membres de la communauté
• Catégories variées
• Système de notation et avis
• Chat intégré avec les vendeurs

📊 PROFIL PERSONNALISABLE
• Photo de profil et bannière
• Informations personnelles
• Statut de présence
• Paramètres de confidentialité

🎨 PERSONNALISATION
• Mode clair et mode sombre
• Choix de couleurs de thème
• Fonds d'écran personnalisés pour les conversations
• Interface intuitive et moderne

🔐 SÉCURITÉ & CONFIDENTIALITÉ
• Authentification sécurisée
• Contrôle de visibilité du profil
• Blocage d'utilisateurs
• Données chiffrées

🌐 MULTILINGUE
• Interface en français et anglais
• Facile à utiliser pour tous

🔔 NOTIFICATIONS CONFIGURABLES
• Personnalisez vos notifications
• Heures de silence
• Notifications par catégorie

💯 POURQUOI DIASPO NIGER ?

✅ Gratuit et sans publicité
✅ Conçu pour et par les Nigériens
✅ Respecte votre vie privée
✅ Mises à jour régulières
✅ Support réactif

Rejoignez dès maintenant des milliers de Nigériens qui utilisent Diaspo Niger pour rester connectés avec leur communauté, où qu'ils soient dans le monde !

📧 Contact & Support
Email : support@diasponiger.com
Site web : https://diaspo-niger.web.app

Connexion, partage, solidarité - C'est ça, Diaspo Niger ! 🇳🇪
```

**Catégorie :**
```
Social
```

**Tags :**
```
diaspora, nigérien, communauté, messagerie, transfert d'argent, événements
```

---

#### 📧 **Coordonnées du Développeur**

**Email :**
```
support@diasponiger.com
```

**Site web :**
```
https://diaspo-niger.web.app
```

**Adresse :**
```
[Votre adresse complète]
```

**Numéro de téléphone :**
```
[Votre numéro]
```

---

#### 🖼️ **Assets Graphiques Requis**

##### 1. **Icône de l'Application**
- **Format :** PNG
- **Taille :** 512 x 512 pixels
- **Fond :** Transparent ou couleur unie
- 📁 Utiliser : `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (redimensionner à 512x512)

##### 2. **Bannière de Fonctionnalité**
- **Format :** PNG ou JPEG
- **Taille :** 1024 x 500 pixels
- **Pas de transparence**
- 💡 Créer une bannière avec le logo et un slogan

##### 3. **Screenshots** (MINIMUM 2, Maximum 8)

**Téléphone :**
- **Taille recommandée :** 1080 x 1920 pixels (ou 1080 x 2340 pour écrans longs)
- **Format :** PNG ou JPEG

**Captures d'écran à inclure :**
1. 📱 **Écran de connexion/bienvenue**
2. 🗺️ **Carte avec membres de la diaspora**
3. 💬 **Messagerie (conversation)**
4. 👥 **Liste des groupes**
5. 💸 **Écran de transfert d'argent**
6. 🏪 **Marketplace**
7. 📅 **Événements**
8. 👤 **Profil utilisateur**

**Comment capturer :**
```bash
# Sur émulateur ou appareil réel
# Lancer l'app en mode release
flutter run --release

# Prendre des screenshots via Android Studio ou directement sur l'appareil
```

##### 4. **Bannière TV** (Optionnel)
- **Taille :** 1280 x 720 pixels

---

#### 📱 **Vidéo Promotionnelle** (Optionnel mais recommandé)

- **Durée :** 30 secondes à 2 minutes
- **Format :** YouTube
- **Contenu suggéré :**
  1. Intro avec logo (3s)
  2. Carte de la diaspora (5s)
  3. Messagerie en action (5s)
  4. Transfert d'argent (5s)
  5. Marketplace (5s)
  6. Call-to-action "Téléchargez maintenant" (3s)

---

### C. Classification du Contenu

**1. Public cible :**
```
Tous publics (13+)
```

**2. Questionnaire de classification :**
- Violence : Non
- Contenu sexuel : Non
- Langage grossier : Non
- Contenu contrôlé : Non
- Interaction utilisateurs : Oui (chat, messagerie)
- Partage d'informations personnelles : Oui
- Achats numériques : Non (mais transferts d'argent)

**3. Publicité :**
```
L'application ne contient pas de publicité
```

---

### D. Politique de Confidentialité

**URL requise :** Créer une page sur votre site web

**Contenu minimal :**
```markdown
# Politique de Confidentialité - Diaspo Niger

## Collecte de Données
Nous collectons :
- Informations de profil (nom, photo, email)
- Localisation (avec consentement)
- Messages et contenus partagés
- Données de transactions

## Utilisation des Données
Vos données sont utilisées pour :
- Fournir les services de l'application
- Améliorer l'expérience utilisateur
- Envoyer des notifications

## Partage de Données
Nous ne vendons jamais vos données.
Vos données sont stockées sur Firebase (Google).

## Sécurité
Chiffrement des données en transit et au repos.

## Vos Droits
Vous pouvez :
- Consulter vos données
- Supprimer votre compte
- Désactiver la localisation

## Contact
support@diasponiger.com

Dernière mise à jour : [Date]
```

**URL :**
```
https://diaspo-niger.web.app/privacy-policy.html
```

---

### E. Conditions d'Utilisation

**URL requise :**
```
https://diaspo-niger.web.app/terms-of-service.html
```

---

### F. Sécurité des Données

**Section « Sécurité des données » :**

**Données collectées :**
- ✅ Informations personnelles (nom, email, photo)
- ✅ Localisation approximative
- ✅ Messages et médias
- ✅ Historique des transactions

**Utilisation :**
- ✅ Fonctionnalités de l'application
- ✅ Communication entre utilisateurs
- ✅ Personnalisation

**Partage :**
- ❌ Pas de partage avec des tiers à des fins publicitaires
- ✅ Stockage sur Firebase (Google Cloud)

**Chiffrement :**
- ✅ Données chiffrées en transit (HTTPS)
- ✅ Données chiffrées au repos

---

### G. Upload de l'APK/AAB

**Production → Créer une release**

1. **Sélectionner le type de release :**
   - Production (pour tous les utilisateurs)
   - Test interne (pour votre équipe)
   - Test fermé (pour testeurs bêta)
   - Test ouvert (bêta publique)

2. **Upload du fichier :**
   - Glisser-déposer `app-release.aab`
   - Attendre la validation (quelques minutes)

3. **Nom de la version :**
```
1.0.0
```

4. **Notes de version** (Ce qui est nouveau) :
```
🎉 Première version de Diaspo Niger !

✨ Fonctionnalités incluses :
• Messagerie instantanée et groupes
• Carte interactive de la diaspora
• Transferts d'argent sécurisés
• Marketplace communautaire
• Gestion d'événements
• Profils personnalisables
• Mode sombre
• Notifications configurables
• Fonds d'écran personnalisables pour les conversations

Rejoignez la communauté Diaspo Niger ! 🇳🇪
```

---

### H. Disponibilité et Tarification

**Pays disponibles :**
```
Tous les pays (ou sélectionner les pays spécifiques)
```

**Pays prioritaires :**
- 🇳🇪 Niger
- 🇫🇷 France  
- 🇺🇸 États-Unis
- 🇨🇦 Canada
- Pays d'Afrique de l'Ouest

**Tarification :**
```
Gratuit
```

---

### I. Soumettre pour Révision

**Avant de soumettre :**
- [ ] Toutes les sections sont complètes
- [ ] Screenshots uploadés (minimum 2)
- [ ] Icône 512x512 uploadée
- [ ] Politique de confidentialité accessible
- [ ] AAB uploadé et validé
- [ ] Classification du contenu complétée

**Temps de révision :** 
- Généralement 1 à 3 jours
- Peut aller jusqu'à 7 jours

**Après approbation :**
- L'application sera publiée automatiquement
- Disponible sur Play Store sous 24h

---

## 6. Monitoring Post-Production

### A. Firebase Console
**URL :** https://console.firebase.google.com

**À surveiller :**
- 📊 **Analytics** : Utilisateurs actifs, événements
- 🐛 **Crashlytics** : Crashes et erreurs
- ⚡ **Performance** : Temps de chargement
- 🔔 **Cloud Messaging** : Taux de livraison des notifications
- 💾 **Firestore** : Usage, quotas
- 🔥 **Functions** : Exécutions, erreurs

### B. Google Play Console
**URL :** https://play.google.com/console

**À surveiller :**
- ⭐ **Avis** : Répondre aux utilisateurs
- 📈 **Statistiques** : Installations, désinstallations
- 🐛 **Rapports de crash** : Crashs signalés par Android
- 👥 **Acquisition** : D'où viennent vos utilisateurs

### C. Alertes à Configurer

**Firebase :**
- Alertes si taux de crash > 1%
- Alertes si quota Firestore > 80%
- Alertes si erreurs Cloud Functions

**Play Console :**
- Notifications pour nouveaux avis
- Alertes pour taux de crash élevé

---

## 7. Checklist Finale

### Avant Publication
- [ ] Version mise à jour dans `pubspec.yaml`
- [ ] Aucune clé API sensible dans le code
- [ ] Mode debug désactivé partout
- [ ] `debugPrint` utilisé au lieu de `print`
- [ ] Toutes les images optimisées
- [ ] Règles Firestore déployées et sécurisées
- [ ] Storage rules déployées
- [ ] Cloud Functions déployées et testées
- [ ] Tests sur plusieurs appareils Android
- [ ] Tests en production locale (`flutter run --release`)
- [ ] Notifications testées (messages, groupes, événements)
- [ ] Transferts d'argent testés
- [ ] Marketplace testé
- [ ] Carte de la diaspora testée
- [ ] Performance vérifiée (pas de lag)
- [ ] Keystore sauvegardé en lieu sûr
- [ ] `key.properties` dans `.gitignore`
- [ ] Politique de confidentialité en ligne
- [ ] Conditions d'utilisation en ligne

### Screenshots à Prendre
- [ ] Écran de bienvenue/connexion
- [ ] Carte de la diaspora
- [ ] Liste de conversations
- [ ] Conversation individuelle
- [ ] Liste de groupes
- [ ] Écran de transfert d'argent
- [ ] Marketplace
- [ ] Liste d'événements
- [ ] Profil utilisateur

### Play Store
- [ ] Application créée dans la console
- [ ] Fiche boutique complétée
- [ ] Description courte et complète rédigées
- [ ] Icône 512x512 uploadée
- [ ] Screenshots uploadés (min 2)
- [ ] Bannière feature uploadée
- [ ] Classification du contenu complétée
- [ ] Politique de confidentialité liée
- [ ] Conditions d'utilisation liées
- [ ] Sécurité des données complétée
- [ ] AAB uploadé
- [ ] Notes de version rédigées
- [ ] Pays de disponibilité sélectionnés
- [ ] Soumis pour révision

---

## 8. Mises à Jour Futures

### Incrémenter la Version
```yaml
# pubspec.yaml
# Actuel: 1.0.0+1
# Nouvelle: 1.0.1+2

version: 1.0.1+2
```

### Workflow de Mise à Jour
```bash
# 1. Modifier le code
# 2. Incrémenter la version
# 3. Tester
flutter run --release

# 4. Build
flutter clean
flutter pub get
flutter build appbundle --release

# 5. Upload sur Play Console
# Production → Nouvelle release → Upload AAB
```

### Types de Versions
- **Patch** (1.0.0 → 1.0.1) : Corrections de bugs
- **Minor** (1.0.0 → 1.1.0) : Nouvelles fonctionnalités
- **Major** (1.0.0 → 2.0.0) : Changements importants

---

## 9. Ressources Utiles

### Documentation
- **Flutter :** https://docs.flutter.dev/deployment/android
- **Play Console :** https://support.google.com/googleplay/android-developer
- **Firebase :** https://firebase.google.com/docs

### Support
- **Email :** support@diasponiger.com
- **Play Console :** Centre d'aide intégré

### Outils
- **App Icon Generator :** https://appicon.co
- **Screenshot Frames :** https://screenshots.pro
- **Video Editor :** DaVinci Resolve (gratuit)

---

## 🎉 Félicitations !

Une fois que votre application sera approuvée, elle sera disponible pour des millions d'utilisateurs sur Google Play Store !

**Prochaines étapes après publication :**
1. 📢 Communiquer sur les réseaux sociaux
2. 👥 Inviter vos premiers utilisateurs
3. 📊 Surveiller les analytics
4. 🐛 Corriger les bugs rapidement
5. ⭐ Encourager les avis positifs
6. 🚀 Préparer les futures fonctionnalités

Bonne chance ! 🍀
