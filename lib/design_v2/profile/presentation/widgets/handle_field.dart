import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';

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
      setState(() => _status =
          available ? _HandleStatus.available : _HandleStatus.taken);
      widget.onChanged(normalized, available);
    });
  }

  @override
  Widget build(BuildContext context) {
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
        suffix = const Icon(Icons.check_circle, color: Color(0xFF1B5E32));
        break;
      case _HandleStatus.taken:
      case _HandleStatus.invalid:
        suffix = const Icon(Icons.error_outline, color: Color(0xFFC23E2D));
        break;
      case _HandleStatus.idle:
        suffix = null;
        break;
    }

    String helper;
    Color helperColor = context.textTertiaryColor;
    switch (_status) {
      case _HandleStatus.available:
        helper = 'Disponible';
        helperColor = const Color(0xFF1B5E32);
        break;
      case _HandleStatus.taken:
        helper = 'Cette poignée est déjà prise';
        helperColor = const Color(0xFFC23E2D);
        break;
      case _HandleStatus.invalid:
        helper = '3 à 20 caractères : lettres, chiffres, _';
        helperColor = const Color(0xFFC23E2D);
        break;
      default:
        helper = 'Votre identifiant public unique (optionnel)';
    }

    return TextFormField(
      controller: _controller,
      onChanged: _onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
      ],
      style: TextStyle(color: context.textPrimaryColor),
      decoration: InputDecoration(
        labelText: 'Nom d\'utilisateur',
        prefixText: '@',
        prefixStyle: TextStyle(color: context.textSecondaryColor, fontSize: 16),
        prefixIcon: const Icon(Icons.alternate_email),
        suffixIcon: suffix,
        helperText: helper,
        helperStyle: TextStyle(color: helperColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
