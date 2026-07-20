import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/audio_room_entity.dart';
import '../providers/audio_room_provider.dart';

/// /audio-rooms/create — full room creation form.
class CreateAudioRoomScreen extends ConsumerStatefulWidget {
  const CreateAudioRoomScreen({super.key});

  @override
  ConsumerState<CreateAudioRoomScreen> createState() =>
      _CreateAudioRoomScreenState();
}

class _CreateAudioRoomScreenState
    extends ConsumerState<CreateAudioRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _ticketPriceCtrl = TextEditingController();
  final _collectionGoalCtrl = TextEditingController();
  final _collectionBeneficiaryCtrl = TextEditingController();

  AudioRoomCategory _category = AudioRoomCategory.general;
  AudioRoomMode _mode = AudioRoomMode.normal;
  CollectionType _collectionType = CollectionType.none;

  bool _isPrivate = false;
  bool _isVideoEnabled = false;
  bool _isRecordingEnabled = true;
  bool _isPaid = false;
  bool _isHeritage = false;
  bool _isLoading = false;

  String? _heritageLanguage;
  String? _linkedEventId;
  String? _linkedGroupId;
  String? _linkedEmbassyId;

  static const _heritageLanguages = [
    'Zarma', 'Hausa', 'Tamasheq', 'Kanouri', 'Peul', 'Arabe', 'Français',
  ];

  static const _categories = [
    (AudioRoomCategory.general, 'Discussion'),
    (AudioRoomCategory.news, 'Actualités'),
    (AudioRoomCategory.culture, 'Culture'),
    (AudioRoomCategory.griot, 'Griot/Conte'),
    (AudioRoomCategory.business, 'Business'),
    (AudioRoomCategory.mentorship, 'Mentorat'),
    (AudioRoomCategory.family, 'Famille'),
    (AudioRoomCategory.official, 'Officiel'),
    (AudioRoomCategory.spirituality, 'Spiritualité'),
    (AudioRoomCategory.education, 'Éducation'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _ticketPriceCtrl.dispose();
    _collectionGoalCtrl.dispose();
    _collectionBeneficiaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final room = await ref
          .read(audioRoomSessionProvider.notifier)
          .createRoom(
            title: _titleCtrl.text.trim(),
            description:
                _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
            isPrivate: _isPrivate,
            isVideoEnabled: _isVideoEnabled,
            isRecordingEnabled: _isRecordingEnabled,
            isPaid: _isPaid,
            ticketPrice: _isPaid && _ticketPriceCtrl.text.isNotEmpty
                ? (double.tryParse(_ticketPriceCtrl.text) ?? 0) * 100 ~/ 1
                : null,
            category: _category,
            mode: _mode,
            collectionType: _collectionType,
            collectionGoal: _collectionType != CollectionType.none &&
                    _collectionGoalCtrl.text.isNotEmpty
                ? (double.tryParse(_collectionGoalCtrl.text) ?? 0) * 100 ~/ 1
                : null,
            collectionBeneficiary: _collectionBeneficiaryCtrl.text.trim().isNotEmpty
                ? _collectionBeneficiaryCtrl.text.trim()
                : null,
            isHeritageContent: _isHeritage,
            heritageLanguage: _isHeritage ? _heritageLanguage : null,
            linkedEventId: _linkedEventId,
            linkedGroupId: _linkedGroupId,
            linkedEmbassyId: _linkedEmbassyId,
          );
      if (room != null && mounted) {
        context.pushReplacement('/audio-rooms/${room.id}',
            extra: {'title': room.title},);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    return Scaffold(
      backgroundColor: dn.surface,
      appBar: _ArHeader(
        title: l10n.audioRoomCreateRoom,
        subtitle: l10n.configCompleteLabel,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            // § 1 — Titre
            _FormSection(
              label: l10n.audioRoomTitleLabel,
              child: TextFormField(
                controller: _titleCtrl,
                style: DNText.serif(size: 16, w: FontWeight.w600, color: dn.onSurface),
                decoration: _inputDecoration(l10n.audioRoomTitleHint, dn),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.audioRoomTitleRequired
                    : null,
              ),
            ),

            // § 2 — Description
            _FormSection(
              label: l10n.audioRoomDescriptionLabel,
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                style: DNText.sans(size: 13, color: dn.onSurface),
                decoration: _inputDecoration(l10n.audioRoomDescriptionHint, dn,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: dn.onSurface4, style: BorderStyle.none),
                    ),),
              ),
            ),

            // § 3 — Catégorie
            _FormSection(
              label: l10n.audioRoomCategoryLabel,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _categories.map((c) {
                  final selected = _category == c.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c.$1),
                    child: _Pill(
                        label: c.$2, active: selected, activeColor: dn.onSurface,),
                  );
                }).toList(),
              ),
            ),

            // § 4 — Mode
            _FormSection(
              label: l10n.audioRoomModeLabel,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  (AudioRoomMode.normal, 'Normal'),
                  (AudioRoomMode.ceremony, 'Cérémonie'),
                  (AudioRoomMode.radio, 'Radio'),
                  (AudioRoomMode.heritage, 'Patrimoine'),
                ].map((m) {
                  final sel = _mode == m.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _mode = m.$1),
                    child: _Pill(label: m.$2, active: sel, activeColor: DNColors.terra),
                  );
                }).toList(),
              ),
            ),

            // § 5–7 — Switches
            _SwitchRow(label: l10n.audioRoomPrivateRoom, value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),),
            _SwitchRow(label: l10n.audioRoomVideoEnabled, value: _isVideoEnabled,
                onChanged: (v) => setState(() => _isVideoEnabled = v),),
            _SwitchRow(label: l10n.audioRoomEnableRecording, value: _isRecordingEnabled,
                onChanged: (v) => setState(() => _isRecordingEnabled = v),),

            // § 8 — Salon payant
            _SwitchRow(label: l10n.audioRoomPaidRoom, value: _isPaid,
                onChanged: (v) => setState(() => _isPaid = v),),
            if (_isPaid) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dn.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.audioRoomTicketPriceField,
                          style: DNText.mono(size: 9, color: dn.onSurface3),),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ticketPriceCtrl,
                        keyboardType: TextInputType.number,
                        style: DNText.serif(size: 22, w: FontWeight.w600, color: dn.onSurface),
                        decoration: _inputDecoration('5.00', dn),
                        validator: _isPaid
                            ? (v) => (v == null || v.isEmpty)
                                ? l10n.audioRoomTicketPriceRequired
                                : null
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Estimation reversée : ~95% après commission',
                        style: DNText.mono(size: 8, color: DNColors.leaf),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // § 9 — Collecte
            _SwitchRow(
              label: l10n.audioRoomEnableFundraising,
              value: _collectionType != CollectionType.none,
              onChanged: (v) => setState(() =>
                  _collectionType =
                      v ? CollectionType.familyEvent : CollectionType.none,),
            ),
            if (_collectionType != CollectionType.none) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    (CollectionType.familyEvent, l10n.familyEventLabel),
                    (CollectionType.emergency, 'Aide urgence'),
                    (CollectionType.communityProject, 'Projet commun.'),
                    (CollectionType.custom, 'Autre'),
                  ].map((ct) {
                    final sel = _collectionType == ct.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _collectionType = ct.$1),
                      child: _Pill(label: ct.$2, active: sel, activeColor: DNColors.leaf),
                    );
                  }).toList(),
                ),
              ),
              _FormSection(
                label: l10n.audioRoomFundraisingGoal,
                child: TextFormField(
                  controller: _collectionGoalCtrl,
                  keyboardType: TextInputType.number,
                  style: DNText.sans(size: 14, color: dn.onSurface),
                  decoration: _inputDecoration('500', dn),
                ),
              ),
              _FormSection(
                label: l10n.audioRoomBeneficiary,
                child: TextFormField(
                  controller: _collectionBeneficiaryCtrl,
                  style: DNText.sans(size: 14, color: dn.onSurface),
                  decoration: _inputDecoration('Nom du bénéficiaire', dn),
                ),
              ),
            ],

            // § 10 — Patrimoine
            _SwitchRow(label: l10n.audioRoomHeritageContent, value: _isHeritage,
                onChanged: (v) => setState(() => _isHeritage = v),),
            if (_isHeritage) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _heritageLanguages.map((lang) {
                    final sel = _heritageLanguage == lang;
                    return GestureDetector(
                      onTap: () => setState(() => _heritageLanguage = lang),
                      child: _Pill(label: lang, active: sel, activeColor: DNColors.ochre),
                    );
                  }).toList(),
                ),
              ),
            ],

            // § 11 — Lié à
            _FormSection(
              label: l10n.audioRoomLinkedTo,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Pill(label: l10n.eventLabel, active: _linkedEventId != null,
                      activeColor: DNColors.teal, onTap: () {},),
                  _Pill(label: l10n.groupLabel, active: _linkedGroupId != null,
                      activeColor: DNColors.teal, onTap: () {},),
                  _Pill(label: l10n.audioRoomEmbassyLink, active: _linkedEmbassyId != null,
                      activeColor: DNColors.teal, onTap: () {},),
                ],
              ),
            ),

            // § 12 — Capacité (read-only)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: dn.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '10 speakers · 1 000 listeners',
                style: DNText.mono(size: 9, color: dn.onSurface3),
              ),
            ),
            const SizedBox(height: 12),

            // Admin lock note
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DNColors.terra.withValues(alpha: dn.isDark ? 0.15 : 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DNColors.terra.withValues(alpha: 0.2)),
              ),
              child: Text(
                '🔒 Fonctionnalités soumises aux règles administrateur.',
                style: DNText.mono(size: 8, color: dn.onSurface2),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CreateFooter(
        isLoading: _isLoading,
        onStart: _start,
        onLater: () => context.push('/audio-rooms/schedule'),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, DNTheme dn, {InputBorder? border}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: DNText.sans(size: 13, color: dn.onSurface4),
        filled: true,
        fillColor: dn.surface2,
        enabledBorder: border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: dn.onSurface4),
            ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DNColors.terra, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DNColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DNColors.danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _ArHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;

  const _ArHeader({required this.title, required this.subtitle});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return AppBar(
      backgroundColor: dn.surface,
      elevation: 0,
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DNText.serif(size: 18, color: dn.onSurface)),
          Text(subtitle, style: DNText.mono(size: 9, color: dn.onSurface3)),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: DNText.mono(size: 9, color: context.dn.onSurface3),),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: DNText.sans(size: 13, color: context.dn.onSurface)),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: DNColors.terra,
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;

  const _Pill({
    required this.label,
    required this.active,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? activeColor : dn.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? activeColor : dn.onSurface4),
        ),
        child: Text(
          label,
          style: DNText.mono(
              size: 9, color: active ? DNColors.paper : dn.onSurface3,),
        ),
      ),
    );
  }
}

class _CreateFooter extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onLater;

  const _CreateFooter({
    required this.isLoading,
    required this.onStart,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    return Container(
      color: dn.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onLater,
              style: OutlinedButton.styleFrom(
                foregroundColor: dn.onSurface,
                side: BorderSide(color: dn.onSurface4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.later, style: DNText.sans(size: 14, color: dn.onSurface)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading ? null : onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: DNColors.terra,
                foregroundColor: DNColors.paper,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text('🎙 ${l10n.startNowLabel}',
                      style: DNText.sans(size: 14, w: FontWeight.w600, color: DNColors.paper),),
            ),
          ),
        ],
      ),
    );
  }
}
