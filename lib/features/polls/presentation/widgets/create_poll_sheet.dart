import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../domain/entities/poll_entity.dart';
import '../providers/poll_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

const _pollAccent = Color(0xFF6B5CE0);

/// Callback de brouillon : reçoit les champs du sondage composé sans les
/// soumettre au repository (cas d'un nouveau post, dont l'id n'existe pas
/// encore au moment de la composition).
typedef PollDraftCallback = void Function(
  String question,
  List<String> optionLabels,
  bool allowMultiple,
  DateTime? endsAt,
);

/// Sheet de creation de sondage, generique (groupe ou post du feed via contextId).
///
/// [onDraft] : si fourni, la soumission n'appelle PAS le repository — elle
/// renvoie les champs composés à l'appelant (voir `create_post_screen.dart`,
/// qui crée le sondage seulement après avoir obtenu l'id du post publié).
/// Rend le sondage cree, ou null (annulation, echec, ou mode brouillon) —
/// l'appelant en a besoin pour publier la bulle dans la conversation.
Future<PollEntity?> showCreatePollSheet(
  BuildContext context, {
  required PollContextType contextType,
  required String contextId,
  PollDraftCallback? onDraft,
}) {
  return showModalBottomSheet<PollEntity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CreatePollSheet(
      contextType: contextType,
      contextId: contextId,
      onDraft: onDraft,
    ),
  );
}

class CreatePollSheet extends ConsumerStatefulWidget {
  final PollContextType contextType;
  final String contextId;
  final PollDraftCallback? onDraft;

  const CreatePollSheet({
    super.key,
    required this.contextType,
    required this.contextId,
    this.onDraft,
  });

  @override
  ConsumerState<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<CreatePollSheet> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultiple = false;
  Duration? _duration = const Duration(days: 3);
  bool _isSubmitting = false;

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
      _optionControllers.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((label) => label.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez une question et au moins 2 options'),
        ),
      );
      return;
    }

    final endsAt = _duration == null ? null : DateTime.now().add(_duration!);

    // Mode brouillon (nouveau post, id pas encore connu) : renvoie les
    // champs à l'appelant sans toucher au repository.
    if (widget.onDraft != null) {
      widget.onDraft!(question, options, _allowMultiple, endsAt);
      Navigator.pop(context);
      return;
    }

    setState(() => _isSubmitting = true);

    final poll = widget.contextType == PollContextType.group
        ? await ref.read(pollActionsNotifierProvider.notifier).createGroupPoll(
              groupId: widget.contextId,
              question: question,
              optionLabels: options,
              allowMultiple: _allowMultiple,
              endsAt: endsAt,
            )
        : await ref.read(pollActionsNotifierProvider.notifier).createPostPoll(
              postId: widget.contextId,
              question: question,
              optionLabels: options,
              allowMultiple: _allowMultiple,
              endsAt: endsAt,
            );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (poll != null) {
      Navigator.pop(context, poll);
    } else {
      // Le message generique a masque pendant des mois un refus RLS sur
      // post_poll_options : on affiche desormais la cause remontee par le
      // notifier quand il y en a une.
      final cause = ref.read(pollActionsNotifierProvider).error?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cause == null || cause.isEmpty
                ? 'Impossible de créer le sondage'
                : 'Impossible de créer le sondage : $cause',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const AppIcon(AppIcon.poll, size: 20, color: _pollAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Créer un sondage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _questionController,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _optionControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[i],
                          maxLength: 100,
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                            border: const OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeOption(i),
                        ),
                    ],
                  ),
                ),
              if (_optionControllers.length < 6)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const AppIcon(AppIcon.add, color: _pollAccent),
                  label: const Text('Ajouter une option'),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.pollMultipleChoice),
                subtitle: const Text('Les membres peuvent voter pour plusieurs options'),
                value: _allowMultiple,
                onChanged: (v) => setState(() => _allowMultiple = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Durée du sondage',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _durationChip('24h', const Duration(hours: 24)),
                  _durationChip('3 jours', const Duration(days: 3)),
                  _durationChip(l10n.days7, const Duration(days: 7)),
                  _durationChip('Illimité', null),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publier le sondage'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationChip(String label, Duration? duration) {
    final isSelected = _duration == duration;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _duration = duration),
      selectedColor: _pollAccent.withValues(alpha: 0.15),
    );
  }
}
