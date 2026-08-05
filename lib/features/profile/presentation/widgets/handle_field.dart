import 'dart:async';

import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../providers/profile_provider.dart';
import '../../../../core/theme/design_kit.dart';

/// Champ de saisie de la poignée publique @handle (§16f) avec vérification de
/// disponibilité débouncée. Réutilisable (config d'onboarding + édition profil).
///
/// Notifie le parent à chaque changement via [onChanged] : la poignée
/// normalisée (minuscules, sans `@`, `null` si vide) et un booléen `isValid`
/// (faux si la poignée est déjà prise ou de format invalide) pour que le parent
/// bloque la sauvegarde le cas échéant.
class HandleField extends ConsumerStatefulWidget {
  final String? initialHandle;
  final String? userId;
  final void Function(String? normalizedHandle, bool isValid) onChanged;

  const HandleField({
    super.key,
    required this.onChanged,
    this.initialHandle,
    this.userId,
  });

  @override
  ConsumerState<HandleField> createState() => _HandleFieldState();
}

enum _HandleStatus { idle, checking, available, taken, invalid }

class _HandleFieldState extends ConsumerState<HandleField> {
  static final _handleRegExp = RegExp(r'^[a-z0-9_]{3,20}$');

  final _controller = TextEditingController();
  _HandleStatus _status = _HandleStatus.idle;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialHandle ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String? _normalized() {
    final raw = _controller.text.trim().replaceAll('@', '').toLowerCase();
    return raw.isEmpty ? null : raw;
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    final normalized = _normalized();

    // Vide ou inchangée → pas de vérification (la poignée reste optionnelle).
    if (normalized == null || normalized == widget.initialHandle) {
      setState(() => _status = _HandleStatus.idle);
      widget.onChanged(normalized, true);
      return;
    }
    if (!_handleRegExp.hasMatch(normalized)) {
      setState(() => _status = _HandleStatus.invalid);
      widget.onChanged(normalized, false);
      return;
    }
    setState(() => _status = _HandleStatus.checking);
    // En cours de vérification : on considère provisoirement invalide pour ne
    // pas laisser sauvegarder avant confirmation.
    widget.onChanged(normalized, false);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final available = await ref
          .read(profileRepositoryProvider)
          .isHandleAvailable(normalized, excludeUserId: widget.userId);
      if (!mounted || _normalized() != normalized) return;
      setState(
        () =>
            _status = available ? _HandleStatus.available : _HandleStatus.taken,
      );
      widget.onChanged(normalized, available);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget? suffix;
    switch (_status) {
      case _HandleStatus.checking:
        suffix = const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
        break;
      case _HandleStatus.available:
        suffix = Icon(
          Icons.check_circle_outline,
          size: 20,
          color: context.successColor,
        );
        break;
      case _HandleStatus.taken:
      case _HandleStatus.invalid:
        suffix = Icon(Icons.error_outline, size: 20, color: context.errorColor);
        break;
      case _HandleStatus.idle:
        suffix = null;
        break;
    }

    // Le texte d'aide dit à quoi sert la poignée tant qu'elle n'est pas
    // vérifiée, puis rend le verdict (§16f : chaque champ dit à quoi il sert).
    String helper;
    Color? helperColor;
    switch (_status) {
      case _HandleStatus.available:
        helper = l10n.handleAvailableHint;
        helperColor = context.successColor;
        break;
      case _HandleStatus.taken:
        helper = l10n.handleTaken;
        helperColor = context.errorColor;
        break;
      case _HandleStatus.invalid:
        helper = l10n.handleFormat;
        helperColor = context.errorColor;
        break;
      default:
        helper = l10n.handleHint;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignFieldLabel(l10n.handleLabel),
        TextFormField(
          controller: _controller,
          onChanged: _onChanged,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
          ],
          style: TextStyle(fontSize: 15.5, color: context.textPrimaryColor),
          decoration: designInputDecoration(
            context,
            hintText: l10n.handleExample,
            helperText: helper,
            helperColor: helperColor,
            prefix: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Text(
                '@',
                style: TextStyle(
                  fontSize: 15.5,
                  color: context.textTertiaryColor,
                ),
              ),
            ),
            suffix: suffix,
          ),
        ),
      ],
    );
  }
}
