import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/embassies/data/models/administrative_request_model.dart';
import '../../../../features/embassies/data/datasources/embassy_remote_datasource.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/embassies/domain/entities/embassy_entity.dart';
import '../../../../shared/widgets/app_icon.dart';

class AdministrativeRequestScreen extends ConsumerStatefulWidget {
  final EmbassyEntity embassy;
  final AdministrativeRequestType? initialType;

  const AdministrativeRequestScreen({
    super.key,
    required this.embassy,
    this.initialType,
  });

  @override
  ConsumerState<AdministrativeRequestScreen> createState() =>
      _AdministrativeRequestScreenState();
}

/// Pièces à joindre par type de démarche (§16d). Propositions indicatives —
/// fichier marqué « non relu » dans le handoff, pas de données officielles
/// disponibles ; à confirmer/ajuster avec un consulat si besoin.
const Map<AdministrativeRequestType, List<String>> _requiredDocuments = {
  AdministrativeRequestType.passportRenewal: [
    'Ancien passeport',
    '2 photos d\'identité récentes',
    'Justificatif de domicile',
    'Copie de l\'acte de naissance',
  ],
  AdministrativeRequestType.passportNewRequest: [
    'Acte de naissance original',
    '2 photos d\'identité récentes',
    'Justificatif de domicile',
    'Carte consulaire ou pièce d\'identité',
  ],
  AdministrativeRequestType.visaApplication: [
    'Passeport valide',
    '2 photos d\'identité récentes',
    'Justificatif d\'hébergement',
    'Billet aller-retour ou réservation',
  ],
  AdministrativeRequestType.birthCertificate: [
    'Copie du livret de famille ou extrait existant',
    'Pièce d\'identité du demandeur',
  ],
  AdministrativeRequestType.marriageCertificate: [
    'Copie de l\'acte de mariage existant',
    'Pièces d\'identité des deux époux',
  ],
  AdministrativeRequestType.deathCertificate: [
    'Copie de l\'acte de décès existant',
    'Pièce d\'identité du demandeur',
  ],
  AdministrativeRequestType.consularId: [
    '2 photos d\'identité récentes',
    'Justificatif de domicile',
    'Passeport ou acte de naissance',
  ],
  AdministrativeRequestType.legalDocument: [
    'Document original à légaliser',
    'Pièce d\'identité',
  ],
  AdministrativeRequestType.laissezPasser: [
    'Déclaration de perte ou de vol (si applicable)',
    '2 photos d\'identité récentes',
    'Toute pièce d\'identité disponible',
  ],
  AdministrativeRequestType.powerOfAttorney: [
    'Pièce d\'identité du mandant',
    'Pièce d\'identité du mandataire',
    'Objet précis de la procuration',
  ],
  AdministrativeRequestType.inscription: [
    'Passeport ou pièce d\'identité',
    'Justificatif de domicile à l\'étranger',
    '1 photo d\'identité',
  ],
  AdministrativeRequestType.other: [
    'Pièce d\'identité',
    'Description détaillée de la demande',
  ],
};

/// Délai indicatif par type de démarche (§16d). Même réserve que
/// [_requiredDocuments] : proposition, pas une donnée officielle.
const Map<AdministrativeRequestType, String> _indicativeDelay = {
  AdministrativeRequestType.passportRenewal: 'Environ 3 à 4 semaines',
  AdministrativeRequestType.passportNewRequest: 'Environ 4 à 6 semaines',
  AdministrativeRequestType.visaApplication: 'Environ 5 à 10 jours ouvrés',
  AdministrativeRequestType.birthCertificate: 'Environ 1 à 2 semaines',
  AdministrativeRequestType.marriageCertificate: 'Environ 1 à 2 semaines',
  AdministrativeRequestType.deathCertificate: 'Environ 1 à 2 semaines',
  AdministrativeRequestType.consularId: 'Environ 2 à 3 semaines',
  AdministrativeRequestType.legalDocument: 'Environ 3 à 5 jours ouvrés',
  AdministrativeRequestType.laissezPasser:
      'Sous 48 à 72 heures (urgence voyage)',
  AdministrativeRequestType.powerOfAttorney: 'Environ 3 à 5 jours ouvrés',
  AdministrativeRequestType.inscription: 'Environ 1 semaine',
  AdministrativeRequestType.other: 'Délai variable selon la demande',
};

class _AdministrativeRequestScreenState
    extends ConsumerState<AdministrativeRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPreFilled = false;

  late AdministrativeRequestType _selectedType;
  final Set<String> _checkedDocuments = {};

  // Pre-filled form controllers
  final _fullNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  final _nationalityController = TextEditingController(text: 'Nigérienne');
  final _currentAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _passportExpiryController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType =
        widget.initialType ?? AdministrativeRequestType.passportRenewal;
    _preFillFromProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    _placeOfBirthController.dispose();
    _nationalityController.dispose();
    _currentAddressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passportNumberController.dispose();
    _passportExpiryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _preFillFromProfile() {
    final user = ref.read(currentUserAsyncProvider).value;
    if (user == null) return;

    final profileAsync = ref.read(userStreamProvider(user.id));
    final profile = profileAsync.value;

    if (profile != null) {
      setState(() {
        _fullNameController.text = profile.displayName ?? '';
        _phoneController.text = profile.phoneNumber ?? '';
        _emailController.text = profile.email ?? '';
        _currentAddressController.text = [
          profile.currentCity,
          profile.currentRegion,
          profile.currentCountry,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        _isPreFilled = true;
      });
    }
  }

  String _getTypeLabel(AdministrativeRequestType type) {
    switch (type) {
      case AdministrativeRequestType.passportRenewal:
        return 'Renouvellement de passeport';
      case AdministrativeRequestType.passportNewRequest:
        return 'Nouvelle demande de passeport';
      case AdministrativeRequestType.visaApplication:
        return 'Demande de visa';
      case AdministrativeRequestType.birthCertificate:
        return 'Acte de naissance';
      case AdministrativeRequestType.marriageCertificate:
        return 'Acte de mariage';
      case AdministrativeRequestType.deathCertificate:
        return 'Acte de décès';
      case AdministrativeRequestType.consularId:
        return 'Carte consulaire';
      case AdministrativeRequestType.legalDocument:
        return 'Document légal';
      case AdministrativeRequestType.laissezPasser:
        return 'Laissez-passer';
      case AdministrativeRequestType.powerOfAttorney:
        return 'Procuration';
      case AdministrativeRequestType.inscription:
        return 'Inscription consulaire';
      case AdministrativeRequestType.other:
        return 'Autre demande';
    }
  }

  String _getTypeDescription(AdministrativeRequestType type) {
    switch (type) {
      case AdministrativeRequestType.passportRenewal:
        return 'Renouvellement d\'un passeport existant arrivant à expiration.';
      case AdministrativeRequestType.passportNewRequest:
        return 'Première demande de passeport ou remplacement d\'un passeport perdu/volé.';
      case AdministrativeRequestType.visaApplication:
        return 'Demande de visa pour les ressortissants étrangers.';
      case AdministrativeRequestType.birthCertificate:
        return 'Copie ou extrait d\'acte de naissance.';
      case AdministrativeRequestType.marriageCertificate:
        return 'Copie ou extrait d\'acte de mariage.';
      case AdministrativeRequestType.deathCertificate:
        return 'Copie ou extrait d\'acte de décès.';
      case AdministrativeRequestType.consularId:
        return 'Carte d\'immatriculation consulaire pour les ressortissants nigériens.';
      case AdministrativeRequestType.legalDocument:
        return 'Légalisation ou certification de documents officiels.';
      case AdministrativeRequestType.laissezPasser:
        return 'Document de voyage temporaire en cas de perte de passeport.';
      case AdministrativeRequestType.powerOfAttorney:
        return 'Procuration pour représentation légale.';
      case AdministrativeRequestType.inscription:
        return 'Inscription au registre des Nigériens à l\'étranger.';
      case AdministrativeRequestType.other:
        return 'Autre type de demande administrative.';
    }
  }

  bool _requiresPassportInfo(AdministrativeRequestType type) {
    return type == AdministrativeRequestType.passportRenewal ||
        type == AdministrativeRequestType.visaApplication;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserAsyncProvider).value;
      if (user == null) throw Exception('Utilisateur non connecté');

      final profileAsync = ref.read(userStreamProvider(user.id));
      final profile = profileAsync.value;

      final request = AdministrativeRequestModel(
        id: '',
        userId: user.id,
        embassyId: widget.embassy.id,
        requestType: _selectedType,
        status: AdministrativeRequestStatus.draft,
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.trim(),
        placeOfBirth: _placeOfBirthController.text.trim(),
        nationality: _nationalityController.text.trim(),
        currentAddress: _currentAddressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        passportNumber:
            _passportNumberController.text.trim().isEmpty
                ? null
                : _passportNumberController.text.trim(),
        passportExpiryDate:
            _passportExpiryController.text.trim().isEmpty
                ? null
                : _passportExpiryController.text.trim(),
        userNotes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
        additionalData: {'checkedDocuments': _checkedDocuments.toList()},
        userName: profile?.displayName ?? user.displayName,
        userPhotoUrl: profile?.photoUrl,
        embassyName: widget.embassy.name,
        embassyCountry: widget.embassy.country,
      );

      final dataSource = EmbassyRemoteDataSourceImpl();
      await dataSource.submitRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande soumise avec succès!'),
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
        title: const Text('Nouvelle demande'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Embassy info
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
                    const AppIcon(AppIcon.bank, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.embassy.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${widget.embassy.city}, ${widget.embassy.country}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pre-filled notice
              if (_isPreFilled)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcon.checkCircle,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Formulaire pré-rempli à partir de votre profil. '
                          'Veuillez vérifier et compléter les informations.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Request type selection
              _buildSectionTitle('Type de demande *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<AdministrativeRequestType>(
                initialValue: _selectedType,
                decoration: _inputDecoration(''),
                items:
                    AdministrativeRequestType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeLabel(type)),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      // Les pièces cochées ne s'appliquent qu'au type
                      // précédent — on repart d'une liste vide.
                      _checkedDocuments.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                _getTypeDescription(_selectedType),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Délai indicatif : ${_indicativeDelay[_selectedType]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pièces à joindre (§16d) : cochées une à une par le
              // demandeur pour confirmer qu'il les a bien réunies.
              _buildSectionTitle('Pièces à joindre'),
              const SizedBox(height: 8),
              ...(_requiredDocuments[_selectedType] ?? []).map(
                (doc) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(doc, style: const TextStyle(fontSize: 13.5)),
                  value: _checkedDocuments.contains(doc),
                  onChanged: (checked) {
                    setState(() {
                      if (checked ?? false) {
                        _checkedDocuments.add(doc);
                      } else {
                        _checkedDocuments.remove(doc);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Personal information
              _buildSectionTitle('Informations personnelles'),
              const SizedBox(height: 16),

              TextFormField(
                controller: _fullNameController,
                decoration: _inputDecoration('Nom complet *'),
                validator:
                    (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dateOfBirthController,
                      decoration: _inputDecoration(
                        'Date de naissance *',
                        'JJ/MM/AAAA',
                      ),
                      validator:
                          (v) => v == null || v.isEmpty ? 'Obligatoire' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _placeOfBirthController,
                      decoration: _inputDecoration('Lieu de naissance'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nationalityController,
                decoration: _inputDecoration('Nationalité'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _currentAddressController,
                decoration: _inputDecoration('Adresse actuelle *'),
                maxLines: 2,
                validator:
                    (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 24),

              // Contact
              _buildSectionTitle('Contact'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: _inputDecoration('Téléphone *'),
                      keyboardType: TextInputType.phone,
                      validator:
                          (v) => v == null || v.isEmpty ? 'Obligatoire' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: _inputDecoration('Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Passport info (conditional)
              if (_requiresPassportInfo(_selectedType)) ...[
                _buildSectionTitle('Informations du passeport'),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passportNumberController,
                        decoration: _inputDecoration('N° de passeport'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _passportExpiryController,
                        decoration: _inputDecoration(
                          'Date d\'expiration',
                          'JJ/MM/AAAA',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Notes
              _buildSectionTitle('Remarques / Informations complémentaires'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: _inputDecoration(
                  '',
                  'Ajoutez des détails supplémentaires si nécessaire...',
                ).copyWith(
                  counterText:
                      _notesController.text.isNotEmpty
                          ? '${_notesController.text.length} caractères'
                          : null,
                ),
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),

              // Warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    AppIcon(
                      AppIcon.warning,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Vous devrez peut-être vous rendre à l\'ambassade avec les documents originaux. '
                        'Conservez votre numéro de suivi.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitRequest,
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
                  label: Text(_isLoading ? 'Envoi...' : 'Soumettre la demande'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  InputDecoration _inputDecoration(String label, [String? hint]) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
