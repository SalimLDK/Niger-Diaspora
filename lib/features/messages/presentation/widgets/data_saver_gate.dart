import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'blurhash_image.dart';

/// Barrière du mode données réduites (§4a) : tant que la personne n'a pas
/// demandé le média, on ne va pas le chercher.
///
/// Le réglage « Mode données réduites » promet « Médias non téléchargés
/// automatiquement en discussion ». Il ne tenait cette promesse nulle part :
/// seul l'envoi la respectait, la réception téléchargeait quoi qu'il arrive.
/// C'est ce composant qui la tient, en n'appelant [builder] qu'une fois le
/// téléchargement demandé.
///
/// Le média envoyé par soi-même n'est jamais masqué : il est déjà local, le
/// cacher ne ferait économiser aucun octet.
class DataSaverGate extends StatefulWidget {
  /// Identifie le message pour se souvenir d'un dévoilement pendant la
  /// session — sans quoi le recyclage de la liste re-masquerait le média à
  /// chaque défilement.
  final String messageId;

  /// Aperçu flou encodé, quand le serveur l'a renvoyé. C'est littéralement
  /// l'« aperçu flouté » de la maquette.
  final String? blurhash;

  /// Poids du fichier en octets. Affiché seulement s'il est connu : pas de
  /// « 0 Ko » inventé quand la donnée manque.
  final int? fileSize;

  /// Média que j'ai envoyé : jamais masqué.
  final bool isMe;

  /// Construit le vrai média. N'est appelé qu'une fois la barrière levée,
  /// donc aucun téléchargement n'est déclenché avant.
  final WidgetBuilder builder;

  const DataSaverGate({
    super.key,
    required this.messageId,
    required this.isMe,
    required this.builder,
    this.blurhash,
    this.fileSize,
  });

  /// Messages dévoilés pendant cette session. En mémoire seulement : au
  /// prochain lancement, le mode données réduites reprend la main.
  static final Set<String> _reveles = <String>{};

  @override
  State<DataSaverGate> createState() => _DataSaverGateState();
}

class _DataSaverGateState extends State<DataSaverGate> {
  bool get _revele => DataSaverGate._reveles.contains(widget.messageId);

  void _telecharger() {
    setState(() => DataSaverGate._reveles.add(widget.messageId));
  }

  /// « 86 Ko », « 1,2 Mo ». Ko sous le mégaoctet, une décimale au-delà.
  String _poids(int octets) {
    if (octets < 1024 * 1024) return '${(octets / 1024).round()} Ko';
    final mo = octets / (1024 * 1024);
    return '${mo.toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final actif = PreferencesService.instance.dataSaverMode;
    if (!actif || widget.isMe || _revele) {
      return widget.builder(context);
    }

    final l10n = AppLocalizations.of(context)!;
    final taille = widget.fileSize;
    final legende =
        taille != null && taille > 0
            ? l10n.mediaBlurredPreviewSize(_poids(taille))
            : l10n.mediaBlurredPreview;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        height: 180,
        color: context.surfaceVariantColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Le flou n'est pas décoratif : c'est tout ce qu'on peut montrer
            // sans dépenser de données.
            if (widget.blurhash != null && widget.blurhash!.isNotEmpty)
              BlurhashImage(blurhash: widget.blurhash!, fit: BoxFit.cover),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    legende,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _telecharger,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.textPrimaryColor,
                      foregroundColor: context.backgroundColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      l10n.download,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
}
