import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/embassy_message_model.dart';
import '../../data/datasources/embassy_remote_datasource.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/embassy_entity.dart';
import '../../../../shared/widgets/app_icon.dart';

class EmbassyMessageScreen extends ConsumerStatefulWidget {
  final EmbassyEntity embassy;

  const EmbassyMessageScreen({super.key, required this.embassy});

  @override
  ConsumerState<EmbassyMessageScreen> createState() =>
      _EmbassyMessageScreenState();
}

class _EmbassyMessageScreenState extends ConsumerState<EmbassyMessageScreen> {
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
        return 'Question générale';
      case EmbassyMessageType.request:
        return 'Demande de service';
      case EmbassyMessageType.complaint:
        return 'Réclamation';
      case EmbassyMessageType.inquiry:
        return 'Renseignement';
      case EmbassyMessageType.followUp:
        return 'Suivi de dossier';
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserAsyncProvider).value;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
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
        title: const Text('Contacter l\'ambassade'),
        backgroundColor: theme.colorScheme.surface,
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
                'Type de message',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<EmbassyMessageType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items:
                    EmbassyMessageType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeLabel(type)),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Subject
              Text(
                'Objet *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'Ex: Demande de renseignements sur le passeport',
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
                'Message *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: 'Décrivez votre demande en détail...',
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
                    return 'Le message est obligatoire';
                  }
                  if (value.length < 20) {
                    return 'Le message doit contenir au moins 20 caractères';
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
                  label: Text(_isLoading ? 'Envoi...' : 'Envoyer le message'),
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
