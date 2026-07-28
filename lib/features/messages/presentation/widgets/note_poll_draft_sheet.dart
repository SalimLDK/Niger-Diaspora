import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';

const _pollAccent = Color(0xFF6B5CE0);

/// Ouvre le sheet de composition d'un ┬½ brouillon de sondage ┬╗ pour ┬½ Mes notes ┬╗.
///
/// Ne cr├®e AUCUN sondage votable : renvoie simplement une note texte structur├®e
/// (question + options), ├á recopier/publier ailleurs. Retourne `null` si annul├®.
Future<String?> showNotePollDraftSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const NotePollDraftSheet(),
  );
}

class NotePollDraftSheet extends StatefulWidget {
  const NotePollDraftSheet({super.key});

  @override
  State<NotePollDraftSheet> createState() => _NotePollDraftSheetState();
}

class _NotePollDraftSheetState extends State<NotePollDraftSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 6) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    final filled =
        _optionControllers.where((c) => c.text.trim().isNotEmpty).length;
    return filled >= 2;
  }

  /// Construit la note texte structur├®e ├á partir de la question et des options.
  String _buildDraft() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final buffer = StringBuffer()
      ..writeln('­ƒôè Sondage (brouillon)')
      ..writeln(question)
      ..writeln();
    for (final option in options) {
      buffer.writeln('Ôù╗´©Å $option');
    }
    return buffer.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: SheetHandle(),
                ),
                Row(
                  children: [
                    const Icon(Icons.poll_outlined, color: _pollAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Brouillon de sondage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Enregistr├® comme note. Pas de vote ÔÇö ├á recopier ou publier ailleurs.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                // Question
                TextField(
                  controller: _questionController,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Votre question',
                    filled: true,
                    fillColor: context.surfaceVariantColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Options',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                ..._optionControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Option ${index + 1}',
                              filled: true,
                              fillColor: context.surfaceVariantColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        if (_optionControllers.length > 2)
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: context.textTertiaryColor,
                              size: 20,
                            ),
                            onPressed: () => _removeOption(index),
                          ),
                      ],
                    ),
                  );
                }),
                if (_optionControllers.length < 6)
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add, size: 18, color: _pollAccent),
                    label: const Text(
                      'Ajouter une option',
                      style: TextStyle(color: _pollAccent),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid
                        ? () => Navigator.pop(context, _buildDraft())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pollAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Enregistrer la note'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
