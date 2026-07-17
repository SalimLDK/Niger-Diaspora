# Audit Module Messagerie - Manquements et Recommandations

> **Date:** 2026-02-24
> **Score Global Messagerie:** 78% (154/197 critères)
> **Score Global Notifications:** 86% (44.5/52 critères)

---

## 🔴 MANQUEMENTS CRITIQUES (❌)

### 1. Liste des Conversations (messages_screen.dart)

| Critère | Manquement |
|---------|------------|
| 1.4.2 | Résultats de recherche non groupés (Messages/Contacts/Groupes) |
| 1.4.3 | Pas de scroll vers le message exact depuis la recherche |

### 2. Écran de Conversation (conversation_screen.dart)

| Critère | Manquement |
|---------|------------|
| 2.2.8 | Pas de détection des numéros de téléphone cliquables |
| 2.2.9 | Pas de support texte riche (gras, italique, barré) |
| 2.2.14 | Pas de partage de localisation |

### 3. Zone de Saisie (message_input.dart)

| Critère | Manquement |
|---------|------------|
| 3.2.3 | Pas de picker emoji intégré |

### 4. Comportements d'Ouverture

| Critère | Manquement |
|---------|------------|
| 4.4.2 | Bandeau conversation archivée manquant |
| 4.6.2 | Citation non restaurée avec le brouillon |
| 4.6.3 | Position de scroll non mémorisée entre sessions |

---

## 🟡 IMPLÉMENTATIONS PARTIELLES (⚠️)

| Critère | État Actuel | Amélioration Nécessaire |
|---------|-------------|------------------------|
| 1.2.4 | Filtre "Favoris" absent | Ajouter filtre pour conversations épinglées |
| 1.4.1 | Recherche dans nom + lastMessage uniquement | Rechercher dans tout l'historique |
| 2.2.18 | Bouton retry affiche icône seulement | Ajouter texte "Réessayer" |
| 4.2.3/4.2.4 | Scroll vers message basique | Améliorer le highlight du message trouvé |
| 4.4.5 / 6.4 | Pas de bandeau persistant | Ajouter indicateur "Mode hors-ligne" visible |
| 7.1.2 | Nom expéditeur affiché | Ajouter mini-avatar par message |
| 8.6.1/8.6.3 | Filtrage mute côté serveur non confirmé | Vérifier implémentation Cloud Functions |
| 9.1 | E2EE service existe | Indicateur visuel cadenas dans UI |
| 9.3 | Bandeau contact bloqué minimal | Enrichir avec options (débloquer, signaler) |

---

## 📋 RECOMMANDATIONS PRIORITAIRES

### 1. Bandeau Mode Hors-Ligne Persistant

**Priorité: CRITIQUE** - Essentiel pour région Sahel

```dart
// Dans app.dart ou scaffold principal
StreamBuilder<ConnectivityResult>(
  stream: Connectivity().onConnectivityChanged,
  builder: (context, snapshot) {
    final isOffline = snapshot.data == ConnectivityResult.none;
    return Column(
      children: [
        if (isOffline)
          MaterialBanner(
            backgroundColor: Colors.orange.shade100,
            content: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange),
                SizedBox(width: 8),
                Text('Mode hors-ligne - Messages en attente'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _retrySync(),
                child: Text('Réessayer'),
              ),
            ],
          ),
        Expanded(child: /* contenu */),
      ],
    );
  },
)
```

### 2. Recherche Full-Text dans Historique

**Priorité: HAUTE** - Fonctionnalité attendue

```dart
// Créer index Firestore pour recherche
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "searchableText", "order": "ASCENDING" }
      ]
    }
  ]
}

// Dans message_provider.dart
Future<List<MessageEntity>> searchInConversation(
  String conversationId,
  String query,
) async {
  final queryLower = query.toLowerCase();
  final snapshot = await _firestore
      .collection('messages')
      .where('conversationId', isEqualTo: conversationId)
      .where('searchableText', arrayContains: queryLower)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();

  return snapshot.docs.map((doc) => MessageModel.fromJson(doc.data())).toList();
}
```

### 3. Emoji Picker Intégré

**Priorité: MOYENNE** - Amélioration UX significative

```dart
// pubspec.yaml
dependencies:
  emoji_picker_flutter: ^1.6.0

// Dans message_input.dart
bool _showEmojiPicker = false;

Column(
  children: [
    // Input existant
    Row(
      children: [
        IconButton(
          icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions),
          onPressed: () {
            setState(() => _showEmojiPicker = !_showEmojiPicker);
            if (_showEmojiPicker) FocusScope.of(context).unfocus();
          },
        ),
        Expanded(child: _buildTextField()),
        // ...
      ],
    ),
    // Emoji picker
    if (_showEmojiPicker)
      SizedBox(
        height: 250,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            _controller.text += emoji.emoji;
          },
          config: Config(
            columns: 7,
            emojiSizeMax: 28,
            bgColor: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      ),
  ],
)
```

### 4. Indicateur E2EE Visuel

**Priorité: MOYENNE** - Renforce confiance utilisateur

```dart
// Dans conversation_screen.dart - AppBar
AppBar(
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(conversation.name),
      if (conversation.isE2EEnabled)
        Row(
          children: [
            Icon(Icons.lock, size: 12, color: Colors.green),
            SizedBox(width: 4),
            Text(
              'Chiffré de bout en bout',
              style: TextStyle(fontSize: 10, color: Colors.green),
            ),
          ],
        ),
    ],
  ),
)
```

### 5. Mini-Avatars dans Conversations de Groupe

**Priorité: MOYENNE** - Meilleure lisibilité

```dart
// Dans message_bubble.dart pour les groupes
if (isGroupConversation && !isCurrentUser)
  Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      CircleAvatar(
        radius: 12,
        backgroundImage: message.senderPhotoUrl != null
            ? CachedNetworkImageProvider(message.senderPhotoUrl!)
            : null,
        child: message.senderPhotoUrl == null
            ? Text(message.senderName[0], style: TextStyle(fontSize: 10))
            : null,
      ),
      SizedBox(width: 6),
      Expanded(child: _buildBubbleContent()),
    ],
  )
```

---

## 🟢 RECOMMANDATIONS BASSES PRIORITÉ

### 6. Partage de Localisation

**Priorité: BASSE** - Effort élevé, impact moyen

**Fichiers à créer/modifier** :
- `lib/features/messages/presentation/widgets/location_picker_modal.dart` (nouveau)
- `lib/features/messages/presentation/widgets/location_message_bubble.dart` (nouveau)
- `lib/features/messages/domain/entities/message_entity.dart`
- `pubspec.yaml`

**Recommandation A - Dépendances** (`pubspec.yaml`) :

```yaml
dependencies:
  geolocator: ^11.0.0
  google_maps_flutter: ^2.5.0
  geocoding: ^2.1.1
```

**Recommandation B - Picker de localisation** (`location_picker_modal.dart`) :

```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerModal extends StatefulWidget {
  final Function(double lat, double lng, String address) onLocationSelected;

  const LocationPickerModal({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _address = '';
  bool _isLoading = true;
  bool _isSendingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      await _getAddressFromLatLng(_selectedLocation!);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _address = '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() => _address = 'Position sélectionnée');
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() => _selectedLocation = latLng);
    _getAddressFromLatLng(latLng);
  }

  Future<void> _sendCurrentLocation() async {
    setState(() => _isSendingCurrentLocation = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _getAddressFromLatLng(LatLng(position.latitude, position.longitude));

      widget.onLocationSelected(
        position.latitude,
        position.longitude,
        _address,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'obtenir la position')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCurrentLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Partager une position',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Bouton position actuelle
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: _isSendingCurrentLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Colors.green),
            ),
            title: const Text('Envoyer ma position actuelle'),
            subtitle: const Text('Position en temps réel'),
            onTap: _isSendingCurrentLocation ? null : _sendCurrentLocation,
          ),

          const Divider(),

          // Carte
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation ?? const LatLng(13.5127, 2.1128), // Niamey par défaut
                          zoom: 15,
                        ),
                        onMapCreated: (controller) => _mapController = controller,
                        onTap: _onMapTap,
                        markers: _selectedLocation != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('selected'),
                                  position: _selectedLocation!,
                                ),
                              }
                            : {},
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),

                      // Adresse sélectionnée
                      if (_selectedLocation != null && _address.isNotEmpty)
                        Positioned(
                          bottom: 80,
                          left: 16,
                          right: 16,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _address,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          // Bouton envoyer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedLocation == null
                      ? null
                      : () {
                          widget.onLocationSelected(
                            _selectedLocation!.latitude,
                            _selectedLocation!.longitude,
                            _address,
                          );
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer cette position'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Recommandation C - Bubble de localisation** (`location_message_bubble.dart`) :

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMessageBubble extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;
  final bool isCurrentUser;

  const LocationMessageBubble({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isCurrentUser,
  });

  Future<void> _openInMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openInMaps,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCurrentUser
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mini carte statique
            SizedBox(
              height: 120,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('location'),
                    position: LatLng(latitude, longitude),
                  ),
                },
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: false,
                liteModeEnabled: true, // Performance
              ),
            ),

            // Adresse
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address.isNotEmpty ? address : 'Position partagée',
                      style: TextStyle(
                        fontSize: 13,
                        color: isCurrentUser ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Recommandation D - Ajouter au message_input.dart** :

```dart
// Dans la liste des options d'attachement
_AttachmentOption(
  icon: Icons.location_on,
  label: 'Position',
  color: Colors.green,
  onTap: () => _showLocationPicker(),
),

Future<void> _showLocationPicker() async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LocationPickerModal(
      onLocationSelected: (lat, lng, address) {
        widget.onSendLocation?.call(lat, lng, address);
      },
    ),
  );
}
```

---

### 7. Support Texte Riche (Gras, Italique, Barré)

**Priorité: BASSE** - Effort moyen, impact faible

**Fichiers à modifier** :
- `lib/features/messages/presentation/widgets/message_bubble.dart`
- `lib/features/messages/presentation/widgets/message_input.dart`

**Recommandation A - Parser de texte riche** :

```dart
// Créer lib/core/utils/rich_text_parser.dart
import 'package:flutter/material.dart';

class RichTextParser {
  /// Parse le texte avec syntaxe WhatsApp/Markdown simple :
  /// *gras* → gras
  /// _italique_ → italique
  /// ~barré~ → barré
  /// `code` → code
  static List<InlineSpan> parse(String text, {TextStyle? baseStyle}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      r'(\*[^*]+\*)|(_[^_]+_)|(~[^~]+~)|(`[^`]+`)',
    );

    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      // Texte avant le match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final matched = match.group(0)!;
      final content = matched.substring(1, matched.length - 1);

      TextStyle style = baseStyle ?? const TextStyle();

      if (matched.startsWith('*')) {
        // Gras
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else if (matched.startsWith('_')) {
        // Italique
        style = style.copyWith(fontStyle: FontStyle.italic);
      } else if (matched.startsWith('~')) {
        // Barré
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      } else if (matched.startsWith('`')) {
        // Code
        style = style.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.withOpacity(0.2),
        );
      }

      spans.add(TextSpan(text: content, style: style));
      lastEnd = match.end;
    }

    // Texte après le dernier match
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans.isEmpty
        ? [TextSpan(text: text, style: baseStyle)]
        : spans;
  }

  /// Widget pratique pour afficher du texte riche
  static Widget buildRichText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text.rich(
      TextSpan(children: parse(text, baseStyle: style)),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
```

**Recommandation B - Utiliser dans message_bubble.dart** :

```dart
// Remplacer le Text simple par RichTextParser
// Avant :
Text(
  message.content,
  style: TextStyle(
    color: isCurrentUser ? Colors.white : Colors.black87,
  ),
)

// Après :
RichTextParser.buildRichText(
  message.content,
  style: TextStyle(
    color: isCurrentUser ? Colors.white : Colors.black87,
  ),
)
```

**Recommandation C - Aide à la saisie dans message_input.dart** (optionnel) :

```dart
// Barre d'outils de formatage au-dessus du TextField
class _FormattingToolbar extends StatelessWidget {
  final TextEditingController controller;

  const _FormattingToolbar({required this.controller});

  void _wrapSelection(String wrapper) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isCollapsed) {
      // Pas de sélection, insérer les marqueurs
      final newText = text.substring(0, selection.start) +
          '$wrapper$wrapper' +
          text.substring(selection.end);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: selection.start + wrapper.length,
      );
    } else {
      // Entourer la sélection
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.substring(0, selection.start) +
          '$wrapper$selectedText$wrapper' +
          text.substring(selection.end);
      controller.text = newText;
      controller.selection = TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.end + (wrapper.length * 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          _FormatButton(
            icon: Icons.format_bold,
            tooltip: 'Gras (*texte*)',
            onPressed: () => _wrapSelection('*'),
          ),
          _FormatButton(
            icon: Icons.format_italic,
            tooltip: 'Italique (_texte_)',
            onPressed: () => _wrapSelection('_'),
          ),
          _FormatButton(
            icon: Icons.strikethrough_s,
            tooltip: 'Barré (~texte~)',
            onPressed: () => _wrapSelection('~'),
          ),
          _FormatButton(
            icon: Icons.code,
            tooltip: 'Code (`texte`)',
            onPressed: () => _wrapSelection('`'),
          ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 18,
      color: Colors.grey[700],
    );
  }
}
```

---

### 8. Détection des Numéros de Téléphone Cliquables

**Priorité: BASSE** - Effort faible, impact moyen

**Fichier à modifier** : `lib/features/messages/presentation/widgets/message_bubble.dart`

**Recommandation** :

```dart
// Ajouter la dépendance
// pubspec.yaml
dependencies:
  flutter_linkify: ^6.0.0
  url_launcher: ^6.2.0

// Dans message_bubble.dart
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

// Remplacer le Text par SelectableLinkify
SelectableLinkify(
  text: message.content,
  style: TextStyle(
    color: isCurrentUser ? Colors.white : Colors.black87,
  ),
  linkStyle: TextStyle(
    color: isCurrentUser ? Colors.white : Theme.of(context).primaryColor,
    decoration: TextDecoration.underline,
  ),
  options: const LinkifyOptions(
    humanize: true,
    removeWww: false,
    looseUrl: true,
  ),
  linkifiers: const [
    UrlLinkifier(),
    EmailLinkifier(),
    PhoneNumberLinkifier(), // Détection des numéros
  ],
  onOpen: (link) async {
    final url = Uri.parse(link.url);

    if (link.url.startsWith('tel:')) {
      // Appel téléphonique
      await launchUrl(url);
    } else if (link.url.startsWith('mailto:')) {
      // Email
      await launchUrl(url);
    } else {
      // URL web - demander confirmation
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ouvrir le lien ?'),
          content: Text(link.url),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ouvrir'),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  },
)

// PhoneNumberLinkifier personnalisé pour les formats africains
class PhoneNumberLinkifier extends Linkifier {
  const PhoneNumberLinkifier();

  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final output = <LinkifyElement>[];

    for (final element in elements) {
      if (element is TextElement) {
        // Regex pour numéros internationaux et locaux
        // Formats: +227 XX XX XX XX, 00227 XX XX XX XX, 227 XX XX XX XX
        final phoneRegex = RegExp(
          r'(\+?\d{1,3}[-.\s]?)?\(?\d{2,3}\)?[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{0,2}',
        );

        final text = element.text;
        var lastEnd = 0;

        for (final match in phoneRegex.allMatches(text)) {
          // Vérifier que c'est un numéro valide (au moins 8 chiffres)
          final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 8) continue;

          if (match.start > lastEnd) {
            output.add(TextElement(text.substring(lastEnd, match.start)));
          }

          final phoneNumber = match.group(0)!;
          output.add(LinkableElement(
            phoneNumber,
            'tel:${phoneNumber.replaceAll(RegExp(r'[\s.-]'), '')}',
          ));

          lastEnd = match.end;
        }

        if (lastEnd < text.length) {
          output.add(TextElement(text.substring(lastEnd)));
        }

        if (lastEnd == 0) {
          output.add(element);
        }
      } else {
        output.add(element);
      }
    }

    return output;
  }
}
```

---

## 📊 RÉSUMÉ DES ACTIONS

| Priorité | Action | Effort | Impact |
|----------|--------|--------|--------|
| 🔴 Critique | Bandeau hors-ligne persistant | Faible | Très élevé |
| 🔴 Haute | Recherche full-text historique | Élevé | Élevé |
| 🟡 Moyenne | Emoji picker | Faible | Moyen |
| 🟡 Moyenne | Indicateur E2EE | Faible | Moyen |
| 🟡 Moyenne | Mini-avatars groupes | Moyen | Moyen |
| 🟢 Basse | Partage localisation | Élevé | Moyen |
| 🟢 Basse | Support texte riche | Moyen | Faible |
| 🟢 Basse | Détection numéros téléphone | Faible | Moyen |

---

## 📈 SCORES PAR SECTION

| Section | Score | Détail |
|---------|-------|--------|
| Liste conversations | 85% | 17/20 |
| Écran conversation | 75% | 30/40 |
| Zone de saisie | 80% | 16/20 |
| Enregistrement audio | 95% | 19/20 |
| Comportements ouverture | 70% | 14/20 |
| Offline-first | 75% | 15/20 |
| Conversations groupe | 80% | 16/20 |
| Notifications | 85% | 17/20 |
| Sécurité/Confidentialité | 63% | 10/16 |
| Performance technique | 100% | 10/10 |

---

# AUDIT SYSTÈME DE NOTIFICATIONS

---

## 🔴 MANQUEMENTS CRITIQUES - NOTIFICATIONS

### 1. Absence de dismiss multi-appareils (Critère 8.2)

**Problème** : Quand l'utilisateur lit un message sur un appareil, la notification reste visible sur ses autres appareils connectés.

**Impact** : Confusion utilisateur, notifications obsolètes qui s'accumulent.

**Fichiers concernés** :
- `lib/features/messages/presentation/providers/message_provider.dart`
- `functions/index.js`
- `lib/core/services/notification_service.dart`

**Recommandation A - Côté Flutter** (`message_provider.dart`) :

```dart
// Dans MarkAsReadNotifier, ajouter l'appel pour dismiss multi-appareils
Future<void> mark(String conversationId) async {
  final userId = ref.read(currentUserProvider)?.uid;
  if (userId == null) return;

  // Marquer comme lu dans Firestore
  await ref.read(messageRepositoryProvider).markAsRead(conversationId, userId);

  // Annuler la notification locale
  await ref.read(notificationServiceProvider).cancelNotificationGroup(
    'messages_$conversationId'
  );

  // Déclencher le dismiss sur les autres appareils via Cloud Function
  try {
    await FirebaseFunctions.instanceFor(region: 'europe-west1')
      .httpsCallable('dismissNotificationOnOtherDevices')
      .call({'conversationId': conversationId});
  } catch (e) {
    // Silencieux - non bloquant
    debugPrint('Failed to dismiss on other devices: $e');
  }
}
```

**Recommandation B - Cloud Function** (`functions/index.js`) :

```javascript
// Ajouter cette nouvelle fonction
exports.dismissNotificationOnOtherDevices = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    const { conversationId } = data;

    if (!conversationId) {
      throw new functions.https.HttpsError('invalid-argument', 'conversationId required');
    }

    // Récupérer les tokens FCM de l'utilisateur
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const fcmTokens = userDoc.data()?.fcmTokens || [];

    if (fcmTokens.length === 0) return { success: true };

    // Envoyer un message data-only pour annuler la notification
    const message = {
      tokens: fcmTokens,
      data: {
        type: 'dismiss_notification',
        conversationId: conversationId,
        action: 'cancel',
      },
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            'content-available': 1,
          },
        },
      },
    };

    try {
      await admin.messaging().sendEachForMulticast(message);
      return { success: true };
    } catch (error) {
      console.error('Error dismissing notifications:', error);
      return { success: false, error: error.message };
    }
  });
```

**Recommandation C - Handler du dismiss** (`notification_service.dart`) :

```dart
// Dans _handleForegroundMessage, ajouter le traitement du dismiss
void _handleForegroundMessage(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];

  // Gérer le dismiss depuis un autre appareil
  if (type == 'dismiss_notification') {
    final conversationId = data['conversationId'];
    if (conversationId != null) {
      cancelNotificationGroup('messages_$conversationId');
      return; // Ne pas afficher de notification
    }
  }

  // ... reste du code existant
}
```

---

## 🟡 MANQUEMENTS IMPORTANTS - NOTIFICATIONS

### 2. Nom du fichier non affiché dans les notifications (Critère 3.5)

**Problème** : Pour les fichiers, la notification affiche "📎 Fichier" au lieu de "📎 document.pdf".

**Impact** : L'utilisateur ne sait pas quel fichier il a reçu sans ouvrir l'app.

**Fichier concerné** : `functions/index.js`

**Recommandation** :

```javascript
// Modifier la fonction getE2EEMessagePreview
function getE2EEMessagePreview(messageType, messageData = {}) {
  switch (messageType) {
    case 'image':
      return '📸 Photo';
    case 'video':
      return '🎥 Vidéo';
    case 'audio':
      return '🎙️ Message vocal';
    case 'document':
    case 'file':
      // Extraire le nom du fichier depuis les métadonnées
      const fileName = messageData.fileName
        || messageData.metadata?.fileName
        || messageData.metadata?.name;
      if (fileName) {
        // Tronquer si trop long
        const displayName = fileName.length > 30
          ? fileName.substring(0, 27) + '...'
          : fileName;
        return `📎 ${displayName}`;
      }
      return '📎 Fichier';
    case 'location':
      return '📍 Position partagée';
    case 'contact':
      return '👤 Contact partagé';
    case 'sticker':
      return '🎨 Sticker';
    default:
      return '🔒 Nouveau message';
  }
}

// Dans onMessageCreated, passer les données du message
const preview = message.e2eeVersion
  ? getE2EEMessagePreview(message.type, message)
  : getMessagePreview(message, message.content);
```

---

### 3. Small icon non personnalisé sur Android (Critère 3.9)

**Problème** : L'icône small (barre de notification) utilise `ic_launcher` par défaut au lieu d'une icône monochrome dédiée.

**Impact** : L'icône apparaît comme un carré gris dans la barre de notification au lieu du logo de l'app.

**Fichiers concernés** :
- `android/app/src/main/res/drawable/ic_notification.xml` (à créer)
- `lib/core/services/notification_service.dart`
- `android/app/src/main/AndroidManifest.xml`

**Recommandation A - Créer l'icône** (`android/app/src/main/res/drawable/ic_notification.xml`) :

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="#FFFFFF">
    <!-- Icône simplifiée de l'app (monochrome) -->
    <!-- Remplacer par le vrai logo Diaspo Niger simplifié -->
    <path
        android:fillColor="@android:color/white"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM12,20c-4.41,0 -8,-3.59 -8,-8s3.59,-8 8,-8 8,3.59 8,8 -3.59,8 -8,8z"/>
</vector>
```

**Recommandation B - Utiliser dans le code** (`notification_service.dart`) :

```dart
// Dans _showLocalNotification et toutes les méthodes de notification
AndroidNotificationDetails(
  channelId,
  channelName,
  channelDescription: channelDescription,
  importance: Importance.high,
  priority: Priority.high,
  icon: 'ic_notification', // Ajouter cette ligne
  // ... autres paramètres
)
```

**Recommandation C - Configurer dans AndroidManifest.xml** :

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_notification" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_color"
    android:resource="@color/notification_color" />
```

---

### 4. iOS thread identifier manquant (Critère 5.7)

**Problème** : Les notifications iOS ne sont pas regroupées par conversation car le `thread-id` n'est pas défini.

**Impact** : Sur iOS, toutes les notifications de messages s'empilent sans organisation.

**Fichier concerné** : `functions/index.js`

**Recommandation** :

```javascript
// Dans onMessageCreated, modifier le payload APNS
const payload = {
  tokens: tokensToNotify,
  notification: {
    title: notifTitle,
    body: notifBody,
  },
  data: {
    // ... données existantes
  },
  android: {
    priority: 'high',
    notification: {
      channelId: 'messages',
      sound: 'default',
      tag: conversationId, // Pour le regroupement Android
    },
  },
  apns: {
    headers: {
      'apns-collapse-id': conversationId, // Collapse les notifications
    },
    payload: {
      aps: {
        sound: 'default',
        badge: 1,
        'thread-id': conversationId, // AJOUTER - Regroupement iOS
        'mutable-content': 1,
      },
    },
  },
};

// Aussi pour les appels dans onCallCreated
apns: {
  headers: {
    'apns-priority': '10',
    'apns-push-type': 'voip',
  },
  payload: {
    aps: {
      sound: 'default',
      badge: 1,
      'content-available': 1,
      'mutable-content': 1,
      'thread-id': `call_${callerId}`, // AJOUTER
      category: 'INCOMING_CALL',
    },
  },
},
```

---

### 5. Permission demandée au démarrage (Critère 7.3.2)

**Problème** : La permission de notification est demandée au lancement de l'app, ce qui réduit le taux d'acceptation.

**Impact** : Les utilisateurs refusent souvent les permissions demandées sans contexte.

**Fichiers concernés** :
- `lib/main.dart`
- `lib/core/services/notification_service.dart`
- `lib/features/messages/presentation/screens/conversation_screen.dart`

**Recommandation A - Retirer la demande au démarrage** (`main.dart`) :

```dart
// Dans _initializeServices, ne pas demander la permission immédiatement
Future<void> _initializeServices() async {
  // ...

  // NE PAS appeler requestPermission() ici
  // Juste initialiser le service sans demander la permission
  await NotificationService.instance.initialize(requestPermission: false);

  // ...
}
```

**Recommandation B - Modifier NotificationService** (`notification_service.dart`) :

```dart
Future<void> initialize({bool requestPermission = true}) async {
  // ... initialisation des channels

  if (requestPermission) {
    await _requestPermission();
  }
}

// Nouvelle méthode publique pour demander plus tard
Future<bool> requestNotificationPermission() async {
  return await _requestPermission();
}

Future<bool> _requestPermission() async {
  if (Platform.isIOS) {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  } else if (Platform.isAndroid) {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  return true;
}
```

**Recommandation C - Demander au moment optimal** (`conversation_screen.dart`) :

```dart
class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  bool _hasCheckedNotificationPermission = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermissionOnFirstMessage();
  }

  Future<void> _checkNotificationPermissionOnFirstMessage() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCheckedNotificationPermission =
      prefs.getBool('notification_permission_checked') ?? false;
  }

  Future<void> _sendMessage(String content) async {
    // Demander la permission avant le premier envoi
    if (!_hasCheckedNotificationPermission) {
      await _requestNotificationPermissionWithContext();
    }

    // ... envoyer le message
  }

  Future<void> _requestNotificationPermissionWithContext() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permission_checked', true);
    _hasCheckedNotificationPermission = true;

    // Vérifier le statut actuel
    final status = await Permission.notification.status;
    if (status.isGranted) return;

    // Afficher une explication avant de demander
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activer les notifications ?'),
        content: const Text(
          'Pour ne pas manquer les réponses de vos contacts, '
          'activez les notifications de messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activer'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      final granted = await ref
        .read(notificationServiceProvider)
        .requestNotificationPermission();

      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Vous pouvez activer les notifications dans les paramètres',
            ),
            action: SnackBarAction(
              label: 'Paramètres',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }
}
```

---

### 6. Gestion du refus de permission insuffisante (Critère 7.3.3)

**Problème** : Si l'utilisateur refuse la permission, il n'y a pas d'indication claire des conséquences ni de moyen facile de réactiver.

**Impact** : L'utilisateur peut ne pas comprendre pourquoi il ne reçoit pas de notifications.

**Fichiers concernés** :
- `lib/features/notifications/presentation/screens/notification_settings_screen.dart`
- `lib/app.dart`

**Recommandation A - Indicateur dans les paramètres** (`notification_settings_screen.dart`) :

```dart
class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _systemPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _checkSystemPermission();
  }

  Future<void> _checkSystemPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      _systemPermissionGranted = status.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres de notification')),
      body: ListView(
        children: [
          // Bannière d'avertissement si permission refusée
          if (!_systemPermissionGranted)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications désactivées',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Les notifications sont bloquées au niveau du système. '
                          'Vous ne recevrez pas d\'alertes pour les nouveaux messages.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (!_systemPermissionGranted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () async {
                  await openAppSettings();
                  // Revérifier après retour
                  Future.delayed(const Duration(seconds: 1), _checkSystemPermission);
                },
                icon: const Icon(Icons.settings),
                label: const Text('Ouvrir les paramètres système'),
              ),
            ),

          const SizedBox(height: 16),

          // ... reste des paramètres existants
        ],
      ),
    );
  }
}
```

**Recommandation B - Vérifier au resume de l'app** (`app.dart`) :

```dart
class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // L'utilisateur revient peut-être des paramètres système
      _checkNotificationPermissionChange();
    }
  }

  Future<void> _checkNotificationPermissionChange() async {
    final status = await Permission.notification.status;
    // Mettre à jour l'état si nécessaire
    ref.read(notificationPermissionProvider.notifier).update(status.isGranted);
  }
}
```

---

### 7. Pas de confirmation visuelle après réponse rapide (Critère 4.4)

**Problème** : Quand l'utilisateur répond depuis la notification, il n'y a pas de feedback visuel confirmant l'envoi.

**Impact** : Incertitude sur le succès de l'envoi, surtout en cas de connexion instable.

**Fichier concerné** : `lib/core/services/background_reply_service.dart`

**Recommandation** :

```dart
// Après l'envoi réussi, mettre à jour la notification
static Future<void> sendReplyFromNotification({
  required String conversationId,
  required String messageText,
  required String senderId,
}) async {
  try {
    // ... code d'envoi existant

    // Afficher une notification de confirmation
    await _showReplyConfirmation(conversationId, messageText);

  } catch (e) {
    // En cas d'échec, afficher une notification d'erreur
    await _showReplyError(conversationId, messageText);
  }
}

static Future<void> _showReplyConfirmation(
  String conversationId,
  String messageText,
) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.show(
    conversationId.hashCode + 1, // ID différent de la notification originale
    'Message envoyé ✓',
    messageText.length > 50
      ? '${messageText.substring(0, 47)}...'
      : messageText,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'messages',
        'Messages',
        channelDescription: 'Notifications de messages',
        importance: Importance.low,
        priority: Priority.low,
        autoCancel: true,
        timeoutAfter: 3000, // Disparaît après 3 secondes
        icon: 'ic_notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    ),
  );
}

static Future<void> _showReplyError(
  String conversationId,
  String messageText,
) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.show(
    conversationId.hashCode + 2,
    'Échec de l\'envoi',
    'Le message sera envoyé dès que possible',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'messages',
        'Messages',
        channelDescription: 'Notifications de messages',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        icon: 'ic_notification',
        color: Colors.orange,
      ),
    ),
  );
}
```

---

## 🟢 AMÉLIORATIONS OPTIONNELLES - NOTIFICATIONS

### 8. Avatar sur toutes les notifications

**Problème** : Certains types de notifications (événements, groupes) n'affichent pas d'avatar.

**Recommandation** (`notification_service.dart`) :

```dart
// Généraliser le téléchargement d'avatar pour tous les types
Future<void> _showNotificationWithAvatar({
  required int id,
  required String title,
  required String body,
  required String channelId,
  String? avatarUrl,
  String? groupKey,
  Map<String, String>? payload,
}) async {
  AndroidBitmap<Object>? largeIcon;

  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    try {
      final file = await DefaultCacheManager().getSingleFile(avatarUrl);
      largeIcon = FilePathAndroidBitmap(file.path);
    } catch (e) {
      debugPrint('Failed to load avatar: $e');
    }
  }

  await _flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        largeIcon: largeIcon,
        // ... autres paramètres
      ),
    ),
    payload: payload != null ? jsonEncode(payload) : null,
  );
}
```

---

### 9. Tonalité de notification personnalisable

**Problème** : L'utilisateur ne peut pas choisir une tonalité personnalisée.

**Fichiers concernés** :
- `android/app/src/main/res/raw/` (créer les fichiers audio)
- `lib/features/settings/presentation/screens/notification_settings_screen.dart`

**Recommandation A - Ajouter les sons** :

```
android/app/src/main/res/raw/
├── notification_default.mp3
├── notification_subtle.mp3
├── notification_chime.mp3
└── notification_pop.mp3
```

**Recommandation B - Sélecteur dans les paramètres** :

```dart
ListTile(
  leading: const Icon(Icons.music_note),
  title: const Text('Tonalité de notification'),
  subtitle: Text(_selectedTone),
  onTap: () => _showToneSelector(),
)

void _showToneSelector() {
  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToneOption('Par défaut', 'notification_default'),
        _ToneOption('Subtile', 'notification_subtle'),
        _ToneOption('Carillon', 'notification_chime'),
        _ToneOption('Pop', 'notification_pop'),
      ],
    ),
  );
}
```

**Recommandation C - Utiliser dans les notifications** :

```dart
AndroidNotificationDetails(
  channelId,
  channelName,
  sound: RawResourceAndroidNotificationSound(selectedTone),
  // ...
)
```

---

### 10. Badge temps réel dans la navigation

**Problème** : Le badge Messages n'est pas toujours synchronisé en temps réel.

**Recommandation** :

```dart
// Dans le widget de navigation principale
class MainNavigationBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(totalUnreadCountProvider);

    return NavigationBar(
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          selectedIcon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.chat_bubble),
          ),
          label: 'Messages',
        ),
        // ... autres destinations
      ],
    );
  }
}
```

---

## 📊 TABLEAU RÉCAPITULATIF NOTIFICATIONS

| # | Issue | Priorité | Effort | Impact |
|---|-------|----------|--------|--------|
| 1 | Dismiss multi-appareils | 🔴 Critique | Moyen | Élevé |
| 2 | Nom du fichier dans notification | 🟡 Important | Faible | Moyen |
| 3 | Small icon Android personnalisé | 🟡 Important | Faible | Moyen |
| 4 | iOS thread identifier | 🟡 Important | Faible | Moyen |
| 5 | Permission au moment optimal | 🟡 Important | Moyen | Élevé |
| 6 | Gestion refus permission | 🟡 Important | Moyen | Moyen |
| 7 | Confirmation réponse rapide | 🟡 Important | Faible | Faible |
| 8 | Avatar sur toutes les notifications | 🟢 Optionnel | Moyen | Faible |
| 9 | Tonalité personnalisable | 🟢 Optionnel | Moyen | Faible |
| 10 | Badge temps réel navigation | 🟢 Optionnel | Faible | Faible |

---

## 📈 SCORES NOTIFICATIONS PAR SECTION

| Section | Score | Pourcentage |
|---------|-------|-------------|
| Déclenchement selon état | 5/5 | 100% |
| Notification in-app | 6/6 | 100% |
| Contenu notification push | 7/9 | 78% |
| Réponse rapide | 3.5/4 | 88% |
| Empilement et regroupement | 5.5/7 | 79% |
| Conversations mutées | 6/7 | 86% |
| Préférences utilisateur | 8.5/10 | 85% |
| Multi-appareils et hors ligne | 3/4 | 75% |

---

## 🎯 ORDRE DE PRIORITÉ RECOMMANDÉ

1. **Dismiss multi-appareils** (critique pour UX multi-device)
2. **iOS thread identifier** (quick win, grande amélioration iOS)
3. **Small icon Android** (quick win, branding)
4. **Permission au moment optimal** (améliore le taux d'acceptation)
5. **Nom du fichier** (quick win)
6. **Gestion refus permission** (améliore la compréhension utilisateur)
7. **Confirmation réponse rapide** (améliore la confiance utilisateur)

---

# AUDIT SYSTÈME D'APPELS AUDIO/VIDÉO

> **Date:** 2026-02-24
> **Score Global Appels:** 70% (67/96 critères)
> **Sections critiques:** Interruptions (43%), Initiation (50%), Appels de groupe (56%)

---

## 📊 SYNTHÈSE PAR SECTION

| Section | ✅ | ⚠️ | ❌ | N/A | Total | Score |
|---------|----|----|----|----|-------|-------|
| 1. Initiation d'appel | 3 | 2 | 1 | 2 | 8 | 50% |
| 2. Réception d'appel | 7 | 0 | 0 | 0 | 7 | 100% |
| 3. Écran appel audio | 9 | 1 | 0 | 0 | 10 | 90% |
| 4. Écran appel vidéo | 7 | 2 | 1 | 1 | 11 | 64% |
| 5. Adaptation réseau | 7 | 2 | 0 | 0 | 9 | 78% |
| 6. Bulles d'appel | 12 | 1 | 4 | 1 | 18 | 67% |
| 7. Appels de groupe | 5 | 2 | 1 | 1 | 9 | 56% |
| 8. Interruptions | 3 | 0 | 4 | 0 | 7 | 43% |
| 9. Historique appels | 6 | 1 | 0 | 0 | 7 | 86% |
| **TOTAL** | **59** | **11** | **11** | **5** | **86** | **70%** |

---

## 🔴 MANQUEMENTS CRITIQUES - APPELS

### 1. Section 1: Initiation d'Appel

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 1.1 | Bouton appel audio visible | ✅ | Présent dans `conversation_screen.dart` |
| 1.2 | Bouton appel vidéo visible | ✅ | Présent dans `conversation_screen.dart` |
| 1.3 | Disabled si contact hors-ligne | ⚠️ | Pas de vérification de présence |
| 1.4 | Feedback visuel au tap | ✅ | Animation et navigation vers `call_screen.dart` |
| 1.5 | Sonnerie retour (ringback) | N/A | Géré par `ringtone_service.dart` |
| 1.6 | Annulation avant réponse | N/A | Bouton raccrocher présent |
| 1.7 | Permission micro/caméra vérifiée | ❌ | **MANQUANT** - Pas de vérification explicite |
| 1.8 | Indicateur "Appel en cours..." | ⚠️ | Texte statique, pas d'animation pulse |

**Fichiers concernés:**
- `lib/features/calls/presentation/screens/call_screen.dart`
- `lib/features/messages/presentation/screens/conversation_screen.dart`
- `lib/core/services/webrtc_service.dart`

---

### 2. Section 3: Écran Appel Audio en Cours

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 3.1 | Photo/avatar contact | ✅ | CachedNetworkImage avec placeholder |
| 3.2 | Nom du contact | ✅ | Affiché en grand |
| 3.3 | Durée de l'appel | ✅ | Timer avec `FontFeature.tabularFigures()` |
| 3.4 | Bouton mute micro | ✅ | Toggle avec feedback visuel |
| 3.5 | Bouton haut-parleur | ✅ | Toggle speaker/earpiece |
| 3.6 | Bouton raccrocher | ✅ | Rouge, centré |
| 3.7 | Upgrade vers vidéo | ✅ | Bouton caméra disponible |
| 3.8 | Indicateur qualité réseau | ✅ | Icône signal avec couleur |
| 3.9 | État de la connexion | ✅ | "Connexion...", "Connecté", etc. |
| 3.10 | Écran off via capteur proximité | ⚠️ | Implémenté mais non testé en production |

**Fichiers concernés:**
- `lib/features/calls/presentation/screens/call_screen.dart`
- `lib/core/services/proximity_service.dart`
- `android/app/src/main/kotlin/MainActivity.kt` (PROXIMITY_SCREEN_OFF_WAKE_LOCK)

---

### 3. Section 4: Écran Appel Vidéo en Cours

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 4.1 | Vidéo distante plein écran | ✅ | RTCVideoView en expanded |
| 4.2 | Vidéo locale en PiP | ✅ | Draggable, coin inférieur droit |
| 4.3 | Bouton basculer caméra | ✅ | Front/Back switch |
| 4.4 | Bouton couper caméra | ✅ | Toggle avec icône |
| 4.5 | Bouton mute micro | ✅ | Présent |
| 4.6 | Bouton raccrocher | ✅ | Présent |
| 4.7 | Contrôles auto-hide (5s) | ✅ | `_controlsVisible` avec timer |
| 4.8 | Tap pour afficher contrôles | ✅ | GestureDetector |
| 4.9 | Indicateur qualité | ⚠️ | Présent mais simplifié |
| 4.10 | Downgrade vers audio seul | ⚠️ | Possible via bouton caméra off |
| 4.11 | Picture-in-Picture système | ❌ | **MANQUANT** - PiP in-app seulement |

**Fichiers concernés:**
- `lib/features/calls/presentation/screens/call_screen.dart`
- `lib/features/calls/presentation/widgets/active_call_indicator.dart`

---

### 4. Section 5: Adaptation Réseau (Contexte Sahel)

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 5.1 | Détection type réseau (2G/3G/4G/5G) | ✅ | `network_info.dart` + native channel |
| 5.2 | Adaptation bitrate automatique | ✅ | `_adjustVideoQualityForNetwork()` |
| 5.3 | Fallback audio si vidéo impossible | ✅ | `_handleNetworkDegradation()` |
| 5.4 | Indicateur visuel qualité réseau | ✅ | Signal icon avec couleur |
| 5.5 | Tentative reconnexion auto | ✅ | ICE restart + exponential backoff |
| 5.6 | Message "Connexion instable" | ⚠️ | Dans logs, pas toujours affiché |
| 5.7 | Codec audio adaptatif (Opus) | ✅ | Opus configuré dans SDP |
| 5.8 | VP8/VP9 selon capacité | ✅ | VP8 préféré, VP9 si disponible |
| 5.9 | Métriques RTT/packet loss | ⚠️ | Collectées mais pas exposées à l'UI |

**Fichiers concernés:**
- `lib/core/services/webrtc_service.dart`
- `lib/core/network/network_info.dart`
- `android/app/src/main/kotlin/MainActivity.kt`

---

### 5. Section 6: Bulles d'Appel dans Conversations

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 6.1.1 | Bulle appel audio sortant | ✅ | `call_message_bubble.dart` |
| 6.1.2 | Bulle appel audio entrant | ✅ | Icône différenciée |
| 6.1.3 | Bulle appel vidéo sortant | ✅ | Icône vidéo |
| 6.1.4 | Bulle appel vidéo entrant | ✅ | Icône vidéo entrante |
| 6.1.5 | Bulle appel manqué | ✅ | Rouge + icône missed |
| 6.1.6 | Bulle appel refusé | ✅ | Style distinct |
| 6.2.1 | Durée affichée | ✅ | Format "mm:ss" ou "hh:mm:ss" |
| 6.2.2 | Horodatage | ✅ | Timestamp en bas |
| 6.2.3 | Icône type d'appel | ✅ | Audio vs vidéo |
| 6.2.4 | Couleur selon statut | ✅ | Vert=connecté, Rouge=manqué |
| 6.3.1 | Tap pour rappeler | ✅ | `onTap: _initiateCallback` |
| 6.3.2 | Long press menu contextuel | ❌ | **MANQUANT** |
| 6.4.1 | Bulle appel groupe sortant | ❌ | **MANQUANT** |
| 6.4.2 | Bulle appel groupe entrant | ❌ | **MANQUANT** |
| 6.4.3 | Bulle appel groupe manqué | ❌ | **MANQUANT** |
| 6.4.4 | Participants affichés | N/A | Non applicable sans 6.4.x |
| 6.5.1 | Animation apparition | ✅ | Slide in |
| 6.5.2 | Regroupement consécutifs | ⚠️ | Pas de regroupement intelligent |

**Fichiers concernés:**
- `lib/features/messages/presentation/widgets/call_message_bubble.dart`
- `lib/features/calls/presentation/providers/call_provider.dart`

---

### 6. Section 7: Appels de Groupe

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 7.1 | Création appel groupe | ✅ | Via `group_call_service.dart` |
| 7.2 | Grille participants vidéo | ✅ | Grid adaptatif 2x2, 3x3 |
| 7.3 | Indication qui parle (VAD) | ✅ | Bordure verte + animation |
| 7.4 | Mute individuel participants | ⚠️ | Admin seulement, pas tous |
| 7.5 | Max participants supportés | ✅ | 4 mesh, 5+ via LiveKit SFU |
| 7.6 | Rejoin après déconnexion | ⚠️ | Pas de rejoin auto fluide |
| 7.7 | Notification appel groupe | ✅ | FCM high-priority |
| 7.8 | E2EE pour appels groupe | ✅ | Via `e2ee_service.dart` |
| 7.9 | Bulle message appel groupe | ❌ | **MANQUANT** |

**Fichiers concernés:**
- `lib/core/services/group_call_service.dart`
- `lib/core/services/livekit_service.dart`
- `lib/features/group_calls/presentation/screens/group_call_screen.dart`

---

### 7. Section 8: Gestion des Interruptions (CRITIQUE)

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 8.1 | Appel GSM entrant - pause app | ❌ | **MANQUANT** - Pas de handler |
| 8.2 | Reprise après appel GSM | ❌ | **MANQUANT** |
| 8.3 | Notification push - pas d'interruption | ✅ | Géré par CallKit/ConnectionService |
| 8.4 | App en background - audio continue | ✅ | Background mode configuré |
| 8.5 | App en background - vidéo pause | ✅ | Vidéo off, audio continue |
| 8.6 | Retour foreground - vidéo reprend | ✅ | Automatique |
| 8.7 | PiP vidéo lors navigation | ❌ | **MANQUANT** - PiP in-app seulement |

**Fichiers concernés:**
- `lib/features/calls/presentation/screens/call_screen.dart`
- `android/app/src/main/kotlin/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`

---

### 8. Section 9: Historique des Appels

| Critère | Description | Statut | Détail |
|---------|-------------|--------|--------|
| 9.1 | Écran dédié historique | ✅ | `call_history_screen.dart` |
| 9.2 | Filtre Tous/Manqués | ✅ | Tabs avec filtres |
| 9.3 | Filtre Entrants/Sortants | ✅ | Inclus dans les tabs |
| 9.4 | Icône type appel | ✅ | Audio/Vidéo distinct |
| 9.5 | Durée affichée | ✅ | Pour appels connectés |
| 9.6 | Tap pour rappeler | ✅ | Navigation vers appel |
| 9.7 | Suppression entrée | ⚠️ | Pas de swipe delete |

**Fichiers concernés:**
- `lib/features/calls/presentation/screens/call_history_screen.dart`

---

## 📋 RECOMMANDATIONS PRIORITAIRES - APPELS

### 1. Vérification des Permissions avant Appel (Critère 1.7)

**Priorité: CRITIQUE** - Empêche les appels de démarrer silencieusement

**Fichier à modifier:** `lib/features/calls/presentation/screens/call_screen.dart`

```dart
import 'package:permission_handler/permission_handler.dart';

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    final isVideo = widget.callType == CallType.video;

    // Vérifier les permissions requises
    final permissions = <Permission>[Permission.microphone];
    if (isVideo) {
      permissions.add(Permission.camera);
    }

    final statuses = await permissions.request();

    // Vérifier si toutes les permissions sont accordées
    final allGranted = statuses.values.every((s) => s.isGranted);

    if (!allGranted) {
      if (mounted) {
        final denied = statuses.entries
            .where((e) => !e.value.isGranted)
            .map((e) => e.key == Permission.microphone ? 'microphone' : 'caméra')
            .join(' et ');

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Permission requise'),
            content: Text(
              'L\'accès au $denied est nécessaire pour passer des appels. '
              'Veuillez l\'autoriser dans les paramètres.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pop(); // Retour à l'écran précédent
                },
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openAppSettings();
                  context.pop();
                },
                child: const Text('Paramètres'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // Permissions OK, initialiser l'appel
    await _initializeCall();
  }

  Future<void> _initializeCall() async {
    // Code existant d'initialisation de l'appel...
  }
}
```

---

### 2. Gestion des Appels GSM (Android) (Critères 8.1, 8.2)

**Priorité: CRITIQUE** - Les appels GSM interrompent l'app sans gestion

**Fichier à créer:** `android/app/src/main/kotlin/com/diasponiger/diaspo_niger/PhoneStateReceiver.kt`

```kotlin
package com.diasponiger.diaspo_niger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import io.flutter.plugin.common.EventChannel

class PhoneStateReceiver : BroadcastReceiver() {
    companion object {
        var eventSink: EventChannel.EventSink? = null
        private var wasInCall = false
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Appel GSM entrant
                eventSink?.success(mapOf(
                    "event" to "gsm_call_incoming",
                    "state" to "ringing"
                ))
                wasInCall = true
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // Appel GSM en cours
                eventSink?.success(mapOf(
                    "event" to "gsm_call_active",
                    "state" to "offhook"
                ))
                wasInCall = true
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                // Appel GSM terminé
                if (wasInCall) {
                    eventSink?.success(mapOf(
                        "event" to "gsm_call_ended",
                        "state" to "idle"
                    ))
                    wasInCall = false
                }
            }
        }
    }
}
```

**Fichier à modifier:** `android/app/src/main/kotlin/MainActivity.kt`

```kotlin
// Ajouter dans configureFlutterEngine
private val GSM_STATE_CHANNEL = "com.diasponiger.diaspo_niger/gsm_state"

// Dans configureFlutterEngine, ajouter:
EventChannel(flutterEngine.dartExecutor.binaryMessenger, GSM_STATE_CHANNEL)
    .setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            PhoneStateReceiver.eventSink = events
        }
        override fun onCancel(arguments: Any?) {
            PhoneStateReceiver.eventSink = null
        }
    })

// Enregistrer le receiver
val phoneStateReceiver = PhoneStateReceiver()
registerReceiver(
    phoneStateReceiver,
    IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
)
```

**Fichier à modifier:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Ajouter la permission -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />

<!-- Enregistrer le receiver -->
<receiver
    android:name=".PhoneStateReceiver"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.PHONE_STATE" />
    </intent-filter>
</receiver>
```

**Fichier à créer:** `lib/core/services/gsm_call_service.dart`

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class GsmCallService {
  static const _channel = EventChannel('com.diasponiger.diaspo_niger/gsm_state');

  StreamSubscription? _subscription;
  final _gsmCallController = StreamController<GsmCallEvent>.broadcast();

  Stream<GsmCallEvent> get gsmCallEvents => _gsmCallController.stream;

  void startListening() {
    if (!Platform.isAndroid) return;

    _subscription = _channel.receiveBroadcastStream().listen((event) {
      final data = Map<String, dynamic>.from(event);
      final eventType = data['event'] as String;

      switch (eventType) {
        case 'gsm_call_incoming':
          _gsmCallController.add(GsmCallEvent.incoming);
          break;
        case 'gsm_call_active':
          _gsmCallController.add(GsmCallEvent.active);
          break;
        case 'gsm_call_ended':
          _gsmCallController.add(GsmCallEvent.ended);
          break;
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }

  void dispose() {
    stopListening();
    _gsmCallController.close();
  }
}

enum GsmCallEvent { incoming, active, ended }
```

**Intégration dans `call_screen.dart`:**

```dart
class _CallScreenState extends ConsumerState<CallScreen> {
  late final GsmCallService _gsmCallService;
  StreamSubscription<GsmCallEvent>? _gsmSubscription;
  bool _wasCallPausedByGsm = false;

  @override
  void initState() {
    super.initState();
    _gsmCallService = GsmCallService();
    _listenToGsmCalls();
  }

  void _listenToGsmCalls() {
    _gsmCallService.startListening();
    _gsmSubscription = _gsmCallService.gsmCallEvents.listen((event) {
      switch (event) {
        case GsmCallEvent.incoming:
        case GsmCallEvent.active:
          // Mettre en pause notre appel VoIP
          _pauseCallForGsm();
          break;
        case GsmCallEvent.ended:
          // Reprendre notre appel VoIP
          if (_wasCallPausedByGsm) {
            _resumeCallAfterGsm();
          }
          break;
      }
    });
  }

  void _pauseCallForGsm() {
    _wasCallPausedByGsm = true;

    // Mettre le micro en mute
    ref.read(webrtcServiceProvider).setMicrophoneEnabled(false);

    // Désactiver la vidéo si c'est un appel vidéo
    if (widget.callType == CallType.video) {
      ref.read(webrtcServiceProvider).setCameraEnabled(false);
    }

    // Afficher un message à l'utilisateur
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appel en pause - Appel téléphonique en cours'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _resumeCallAfterGsm() {
    _wasCallPausedByGsm = false;

    // Réactiver le micro
    ref.read(webrtcServiceProvider).setMicrophoneEnabled(true);

    // Réactiver la vidéo si c'était un appel vidéo et que la caméra était activée
    if (widget.callType == CallType.video && _wasCameraEnabledBeforeGsm) {
      ref.read(webrtcServiceProvider).setCameraEnabled(true);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appel repris'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _gsmSubscription?.cancel();
    _gsmCallService.dispose();
    super.dispose();
  }
}
```

---

### 3. Picture-in-Picture Système (Android) (Critères 4.11, 8.7)

**Priorité: HAUTE** - Améliore considérablement l'UX multitâche

**Fichier à modifier:** `android/app/src/main/AndroidManifest.xml`

```xml
<activity
    android:name=".MainActivity"
    ...
    android:supportsPictureInPicture="true"
    android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation">
```

**Fichier à modifier:** `android/app/src/main/kotlin/MainActivity.kt`

```kotlin
import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational

class MainActivity : FlutterActivity(), SensorEventListener {
    private val PIP_CHANNEL = "com.diasponiger.diaspo_niger/pip"
    private var isInPipMode = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ... code existant ...

        // PiP channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPipMode" -> {
                        val success = enterPipMode()
                        result.success(success)
                    }
                    "isPipSupported" -> {
                        result.success(isPipSupported())
                    }
                    "isInPipMode" -> {
                        result.success(isInPipMode)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
               packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPipMode(): Boolean {
        if (!isPipSupported()) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(9, 16)) // Portrait
                .build()

            return try {
                enterPictureInPictureMode(params)
                true
            } catch (e: Exception) {
                Log.e("PiP", "Failed to enter PiP: ${e.message}")
                false
            }
        }
        return false
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isInPipMode = isInPictureInPictureMode

        // Notifier Flutter
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, PIP_CHANNEL).invokeMethod(
                "onPipModeChanged",
                isInPictureInPictureMode
            )
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Auto-enter PiP si un appel vidéo est en cours
        // Le flag sera défini par Flutter
        if (shouldAutoEnterPip) {
            enterPipMode()
        }
    }
}
```

**Fichier à créer:** `lib/core/services/pip_service.dart`

```dart
import 'dart:io';
import 'package:flutter/services.dart';

class PipService {
  static const _channel = MethodChannel('com.diasponiger.diaspo_niger/pip');

  static Future<bool> get isSupported async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isPipSupported') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> get isInPipMode async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isInPipMode') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> enterPipMode() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('enterPipMode') ?? false;
    } catch (e) {
      return false;
    }
  }

  static void listenToPipChanges(void Function(bool isInPip) callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        callback(call.arguments as bool);
      }
    });
  }
}
```

**Intégration dans `call_screen.dart`:**

```dart
class _CallScreenState extends ConsumerState<CallScreen> with WidgetsBindingObserver {
  bool _isInPipMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPipListener();
  }

  void _setupPipListener() {
    PipService.listenToPipChanges((isInPip) {
      setState(() => _isInPipMode = isInPip);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive &&
        widget.callType == CallType.video &&
        _callState.isConnected) {
      // Auto-enter PiP quand l'utilisateur quitte l'app
      PipService.enterPipMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    // En mode PiP, afficher une UI minimale
    if (_isInPipMode) {
      return _buildPipModeUI();
    }

    // UI normale...
  }

  Widget _buildPipModeUI() {
    return Scaffold(
      body: Stack(
        children: [
          // Vidéo distante plein écran
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          // Bouton raccrocher simple
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                onPressed: _endCall,
                icon: const Icon(Icons.call_end, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

---

### 4. Menu Contextuel Long Press sur Bulles d'Appel (Critère 6.3.2)

**Priorité: MOYENNE** - Améliore l'interaction avec l'historique

**Fichier à modifier:** `lib/features/messages/presentation/widgets/call_message_bubble.dart`

```dart
class CallMessageBubble extends StatelessWidget {
  // ... propriétés existantes ...

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPress: () => _showContextMenu(context),
      child: _buildBubbleContent(context),
    );
  }

  void _showContextMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Options
              ListTile(
                leading: Icon(
                  message.callType == CallType.video
                      ? Icons.videocam
                      : Icons.call,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(l10n.callBack),
                subtitle: Text(
                  message.callType == CallType.video
                      ? l10n.videoCall
                      : l10n.audioCall,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _initiateCallback(context);
                },
              ),

              // Option pour appel audio si c'était un appel vidéo
              if (message.callType == CallType.video)
                ListTile(
                  leading: const Icon(Icons.call),
                  title: Text(l10n.callBackAsAudio),
                  onTap: () {
                    Navigator.pop(context);
                    _initiateCallback(context, forceAudio: true);
                  },
                ),

              // Copier les détails
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.copyCallDetails),
                onTap: () {
                  Navigator.pop(context);
                  _copyCallDetails(context);
                },
              ),

              // Supprimer
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  l10n.deleteCallEntry,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _copyCallDetails(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeStr = message.callType == CallType.video ? l10n.videoCall : l10n.audioCall;
    final statusStr = _getStatusString(l10n);
    final durationStr = message.duration != null
        ? _formatDuration(message.duration!)
        : '-';

    final details = '''
$typeStr
${l10n.status}: $statusStr
${l10n.duration}: $durationStr
${l10n.date}: ${_formatDateTime(message.timestamp)}
''';

    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.copiedToClipboard)),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCallEntry),
        content: Text(l10n.deleteCallEntryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete?.call(message.id);
    }
  }
}
```

---

### 5. Bulles de Message pour Appels de Groupe (Critères 6.4.x)

**Priorité: MOYENNE** - Cohérence avec les appels 1:1

**Fichier à créer:** `lib/features/messages/presentation/widgets/group_call_message_bubble.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../group_calls/domain/entities/group_call_entity.dart';

class GroupCallMessageBubble extends StatelessWidget {
  final GroupCallMessageEntity message;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final Function(String)? onDelete;

  const GroupCallMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final isMissed = message.status == GroupCallStatus.missed;
    final isOngoing = message.status == GroupCallStatus.ongoing;

    Color iconColor;
    Color bgColor;
    IconData icon;

    if (isMissed) {
      iconColor = Colors.red;
      bgColor = Colors.red.withOpacity(0.1);
      icon = Icons.phone_missed;
    } else if (isOngoing) {
      iconColor = Colors.green;
      bgColor = Colors.green.withOpacity(0.1);
      icon = Icons.groups;
    } else {
      iconColor = isCurrentUser ? theme.primaryColor : Colors.grey[600]!;
      bgColor = isCurrentUser
          ? theme.primaryColor.withOpacity(0.1)
          : Colors.grey.withOpacity(0.1);
      icon = message.isVideoCall ? Icons.videocam : Icons.call;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),

            const SizedBox(width: 12),

            // Informations
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    _getTitle(l10n),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMissed ? Colors.red : null,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Participants (avatars empilés)
                  _buildParticipantsRow(),

                  const SizedBox(height: 4),

                  // Durée et heure
                  Row(
                    children: [
                      if (message.duration != null) ...[
                        Text(
                          _formatDuration(message.duration!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Indicateur appel en cours
            if (isOngoing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(),
                    const SizedBox(width: 4),
                    Text(
                      l10n.joinCall,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsRow() {
    final maxDisplay = 4;
    final participants = message.participants;
    final displayCount = participants.length > maxDisplay
        ? maxDisplay
        : participants.length;
    final extraCount = participants.length - maxDisplay;

    return SizedBox(
      height: 24,
      child: Stack(
        children: [
          for (var i = 0; i < displayCount; i++)
            Positioned(
              left: i * 16.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: participants[i].photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: participants[i].photoUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Text(
                              participants[i].name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: displayCount * 16.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTitle(AppLocalizations l10n) {
    switch (message.status) {
      case GroupCallStatus.missed:
        return l10n.missedGroupCall;
      case GroupCallStatus.ongoing:
        return l10n.ongoingGroupCall;
      case GroupCallStatus.ended:
        if (isCurrentUser) {
          return message.isVideoCall
              ? l10n.outgoingGroupVideoCall
              : l10n.outgoingGroupAudioCall;
        }
        return message.isVideoCall
            ? l10n.incomingGroupVideoCall
            : l10n.incomingGroupAudioCall;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  void _showContextMenu(BuildContext context) {
    // Similar to CallMessageBubble context menu
    // ...
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
```

**Clés de localisation à ajouter** (`lib/l10n/app_fr.arb` et `app_en.arb`):

```json
{
  "missedGroupCall": "Appel de groupe manqué",
  "ongoingGroupCall": "Appel de groupe en cours",
  "outgoingGroupVideoCall": "Appel vidéo de groupe",
  "outgoingGroupAudioCall": "Appel audio de groupe",
  "incomingGroupVideoCall": "Appel vidéo de groupe reçu",
  "incomingGroupAudioCall": "Appel audio de groupe reçu",
  "joinCall": "Rejoindre",
  "callBack": "Rappeler",
  "callBackAsAudio": "Rappeler en audio",
  "copyCallDetails": "Copier les détails",
  "deleteCallEntry": "Supprimer",
  "deleteCallEntryConfirm": "Voulez-vous supprimer cette entrée d'appel ?"
}
```

---

## 📊 RÉSUMÉ DES ACTIONS - APPELS

| Priorité | Action | Effort | Impact | Critères |
|----------|--------|--------|--------|----------|
| 🔴 Critique | Vérification permissions avant appel | Faible | Élevé | 1.7 |
| 🔴 Critique | Gestion appels GSM (Android) | Élevé | Élevé | 8.1, 8.2 |
| 🟠 Haute | PiP système Android | Élevé | Élevé | 4.11, 8.7 |
| 🟡 Moyenne | Menu contextuel long press | Faible | Moyen | 6.3.2 |
| 🟡 Moyenne | Bulles appels de groupe | Moyen | Moyen | 6.4.x |
| 🟢 Basse | Indicateur "Connexion instable" | Faible | Moyen | 5.6 |
| 🟢 Basse | Métriques RTT/packet loss UI | Moyen | Faible | 5.9 |
| 🟢 Basse | Swipe delete historique | Faible | Faible | 9.7 |

---

## 🎯 ORDRE DE PRIORITÉ RECOMMANDÉ - APPELS

1. **Vérification permissions** (quick win, évite les bugs silencieux)
2. **Gestion appels GSM** (critique pour UX téléphonie traditionnelle)
3. **PiP système Android** (améliore considérablement le multitâche)
4. **Menu contextuel bulles** (améliore les interactions)
5. **Bulles appels de groupe** (cohérence avec le reste de l'app)

---

*Généré automatiquement lors de l'audit du module messagerie, notifications et appels*
