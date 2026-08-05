import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/embassy_message_model.dart';
import '../../data/datasources/embassy_remote_datasource.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/embassy_entity.dart';
import '../../../../shared/widgets/app_icon.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class EmbassyMessageScreen extends ConsumerStatefulWidget {
  final EmbassyEntity embassy;

  const EmbassyMessageScreen({super.key, required this.embassy});

  @override
  ConsumerState<EmbassyMessageScreen> createState() =>
      _EmbassyMessageScreenState();
}

class _EmbassyMessageScreenState extends ConsumerState<EmbassyMessageScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  EmbassyMessageType _selectedType = EmbassyMessageType.general;
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _getTypeLabel(EmbassyMessageType type) {
    switch (type) {
      case EmbassyMessageType.general:
        return l10n.embassyMessageGeneral;
      case EmbassyMessageType.request:
        return l10n.embassyMessageRequest;
      case EmbassyMessageType.complaint:
        return l10n.embassyMessageComplaint;
      case EmbassyMessageType.inquiry:
        return l10n.embassyMessageInquiry;
      case EmbassyMessageType.followUp:
        return l10n.embassyMessageFollowUp;
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserAsyncProvider).value;
      if (user == null) {
        throw Exception(l10n.userNotLoggedIn);
      }

      final profileAsync = ref.read(userStreamProvider(user.id));
      final profile = profileAsync.value;

      final dataSource = EmbassyRemoteDataSourceImpl();
      await dataSource.sendMessageToEmbassy(
        embassyId: widget.embassy.id,
        userId: user.id,
        subject: _subjectController.text.trim(),
        content: _contentController.text.trim(),
        messageType: _selectedType,
        userName: profile?.displayName ?? user.displayName,
        userPhotoUrl: profile?.photoUrl,
        userEmail: profile?.email ?? user.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message envoyé avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const DesignTitle('Contacter l\'ambassade', size: 22),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Embassy info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: const AppIcon(
                        AppIcon.bank,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.embassy.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${widget.embassy.city}, ${widget.embassy.country}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Message type
              Text(
                l10n.embassyMessageType,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    EmbassyMessageType.values.map((type) {
                      final isSelected = type == _selectedType;
                      return ChoiceChip(
                        label: Text(_getTypeLabel(type)),
                        selected: isSelected,
                        onSelected:
                            (_) => setState(() => _selectedType = type),
                        selectedColor: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        labelStyle: TextStyle(
                          color:
                              isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                          fontWeight:
                              isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),

              // Subject
              Text(
                l10n.embassySubject,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: l10n.embassySubjectHint,
                  helperText: 'Au moins 5 caractères',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'L\'objet est obligatoire';
                  }
                  if (value.length < 5) {
                    return 'L\'objet doit contenir au moins 5 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Content
              Text(
                l10n.embassyMessage,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: l10n.describeRequest,
                  helperText: 'Au moins 20 caractères',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  counterText:
                      _contentController.text.isNotEmpty
                          ? '${_contentController.text.length}/1000 caractères'
                          : '0/1000 caractères',
                ),
                maxLines: 8,
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.embassyMessageRequired;
                  }
                  if (value.length < 20) {
                    return l10n.embassyMessageMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    AppIcon(
                      AppIcon.info,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Votre message sera transmis à l\'ambassade. '
                        'Vous recevrez une notification lors de la réponse.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const AppIcon(AppIcon.send),
                  label: Text(_isLoading ? l10n.embassySending : l10n.embassySendMessage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
