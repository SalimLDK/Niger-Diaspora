import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/administrative_request_model.dart';
import '../../data/models/demarche_model.dart';
import '../../data/repositories/demarches_repository_impl.dart';
import '../../data/datasources/embassy_remote_datasource.dart';
import '../providers/demarches_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/embassy_entity.dart';
import '../../../../shared/widgets/app_icon.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/errors/message_erreur.dart';

class AdministrativeRequestScreen extends ConsumerStatefulWidget {
  final EmbassyEntity embassy;

  /// Démarche présélectionnée, par son identifiant de catalogue
  /// (« carte_consulaire », « prorogation_passeport »…).
  ///
  /// Remplace l'ancien `initialType` : le type de demande ne suffisait pas à
  /// désigner une démarche, six d'entre elles partageant `legalDocument`.
  final String? initialDemarcheId;

  const AdministrativeRequestScreen({
    super.key,
    required this.embassy,
    this.initialDemarcheId,
  });

  @override
  ConsumerState<AdministrativeRequestScreen> createState() =>
      _AdministrativeRequestScreenState();
}

// Les pièces à joindre et le coût viennent désormais du catalogue
// `demarchesCatalogueProvider` (Supabase, puis cache, puis asset embarqué).
//
// Deux tables codées en dur vivaient ici : `_requiredDocuments`, des pièces
// « propositions indicatives », et `_indicativeDelay`, des délais
// entièrement inventés — « Environ 3 à 4 semaines », « Sous 48 à 72 heures
// (urgence voyage) » — affichés en gras dans la couleur primaire, donc lus
// comme officiels. La source du ministère ne publie AUCUN délai : il n'y a
// pas de table de remplacement, l'écran dit maintenant que le délai n'est
// pas communiqué.

class _AdministrativeRequestScreenState
    extends ConsumerState<AdministrativeRequestScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPreFilled = false;

  /// Démarche choisie, par identifiant de catalogue.
  ///
  /// Volontairement pas un objet [Demarche] : le catalogue arrive de façon
  /// asynchrone, et garder une copie de l'objet obligerait à la resynchroniser
  /// quand le chargement passe du cache au serveur. L'identifiant, lui, reste
  /// valable quelle que soit la source.
  String? _selectedDemarcheId;
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
    // Pas de démarche par défaut ici : le catalogue n'est pas encore chargé.
    // `_demarcheChoisie` retombe sur la première du catalogue tant que rien
    // n'est sélectionné — la carte consulaire, prérequis de 18 des 20 autres.
    _selectedDemarcheId = widget.initialDemarcheId;
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
    // `valueOrNull`, jamais `.value` : sur un AsyncValue en erreur, `.value`
    // RELEVE l'erreur au lieu de rendre null. Hors ligne,
    // `userStreamProvider` echoue (lecture Supabase `users`), et comme cet
    // appel part d'`initState` la levee se produit avant tout rendu -- ecran
    // rouge, sans que le `when` du catalogue soit meme atteint. Vu sur
    // SM A515F le 2026-09-07, mode avion.
    final user = ref.read(currentUserAsyncProvider).valueOrNull;
    if (user == null) return;

    final profileAsync = ref.read(userStreamProvider(user.id));
    final profile = profileAsync.valueOrNull;

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

  /// Démarche affichée : celle qui est choisie, sinon la première du
  /// catalogue (la carte consulaire, prérequis de presque tout le reste).
  Demarche? _demarcheChoisie(DemarchesCatalogue catalogue) =>
      catalogue.parId(_selectedDemarcheId) ?? catalogue.premiere;

  /// Le bloc « informations passeport » ne concerne que la prorogation, seule
  /// démarche qui parte d'un passeport existant. La première demande, elle,
  /// n'en a précisément pas.
  bool _requiresPassportInfo(Demarche? demarche) =>
      demarche?.typeDemande == AdministrativeRequestType.passportRenewal;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Meme raison qu'en pre-remplissage : `.value` releverait l'erreur du
      // provider au lieu de rendre null, et l'envoi echouerait sur une panne
      // de lecture de profil plutot que sur l'ecriture elle-meme.
      final user = ref.read(currentUserAsyncProvider).valueOrNull;
      if (user == null) throw Exception(l10n.userNotLoggedIn);

      final profileAsync = ref.read(userStreamProvider(user.id));
      final profile = profileAsync.valueOrNull;

      // Le catalogue est forcément résolu ici : le formulaire n'est rendu
      // qu'une fois chargé. Le `?.` couvre le cas théorique d'une invalidation
      // entre le rendu et l'envoi.
      final catalogue =
          ref.read(demarchesCatalogueProvider).valueOrNull?.catalogue;
      final demarche =
          catalogue == null ? null : _demarcheChoisie(catalogue);

      final request = AdministrativeRequestModel(
        id: '',
        userId: user.id,
        embassyId: widget.embassy.id,
        // Le type reste la colonne historique, mais il ne suffit plus à
        // désigner la démarche : `legalDocument` en couvre six. L'identifiant
        // exact part dans `additionalData`, sans quoi l'agent consulaire ne
        // saurait pas laquelle des six a été demandée.
        requestType: demarche?.typeDemande ?? AdministrativeRequestType.other,
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
        additionalData: {
          'checkedDocuments': _checkedDocuments.toList(),
          if (demarche != null) ...{
            'demarcheId': demarche.id,
            'demarcheTitre': demarche.titre,
            'demarcheRubrique': demarche.rubrique,
          },
        },
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
            content: Text(messageErreurUsager(e)),
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
    final catalogueAsync = ref.watch(demarchesCatalogueProvider);

    return catalogueAsync.when(
      loading:
          () => _echafaudage(const Center(child: CircularProgressIndicator())),
      error: (erreur, _) => _echafaudage(_erreurCatalogue(erreur)),
      data: _formulaire,
    );
  }

  /// Chrome commun aux trois états du catalogue.
  Widget _echafaudage(Widget corps) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: DesignTitle(l10n.newRequest, size: 22),
      ),
      body: corps,
    );
  }

  /// N'arrive que si les trois sources ont échoué — donc en pratique si
  /// l'asset embarqué lui-même est illisible, le repli local ne dépendant
  /// d'aucun réseau. Affiche l'erreur plutôt qu'un formulaire vide.
  Widget _erreurCatalogue(Object erreur) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(AppIcon.warning, size: 40, color: Colors.orange[700]),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger la liste des démarches.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$erreur',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          DesignSecondaryButton(
            label: 'Réessayer',
            onPressed: () => ref.invalidate(demarchesCatalogueProvider),
          ),
        ],
      ),
    );
  }

  Widget _formulaire(CatalogueCharge charge) {
    final theme = Theme.of(context);
    final catalogue = charge.catalogue;
    final demarche = _demarcheChoisie(catalogue);

    return _echafaudage(
      Form(
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

              // Démarche demandée
              _buildSectionTitle(l10n.embassyRequestType),
              const SizedBox(height: 8),
              DesignDropdown<String>(
                value: demarche?.id,
                hintText: 'Choisir une démarche',
                items: _itemsDemarches(catalogue),
                onChanged: _changerDemarche,
              ),
              ..._detailsDemarche(demarche, charge),
              const SizedBox(height: 16),

              // Personal information
              _buildSectionTitle(l10n.personalInfo),
              const SizedBox(height: 16),

              TextFormField(
                controller: _fullNameController,
                decoration: _inputDecoration(l10n.embassyFullName),
                validator:
                    (v) => v == null || v.isEmpty ? l10n.embassyFieldRequired : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dateOfBirthController,
                      decoration: _inputDecoration(
                        l10n.embassyDateOfBirth,
                        l10n.embassyDateFormat,
                      ),
                      validator:
                          (v) => v == null || v.isEmpty ? l10n.embassyFieldRequiredShort : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _placeOfBirthController,
                      decoration: _inputDecoration(l10n.embassyPlaceOfBirth),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nationalityController,
                decoration: _inputDecoration(l10n.embassyNationality),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _currentAddressController,
                decoration: _inputDecoration(l10n.embassyCurrentAddress),
                maxLines: 2,
                validator:
                    (v) => v == null || v.isEmpty ? l10n.embassyFieldRequired : null,
              ),
              const SizedBox(height: 24),

              // Contact
              _buildSectionTitle(l10n.contact),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: _inputDecoration(l10n.embassyPhone),
                      keyboardType: TextInputType.phone,
                      validator:
                          (v) => v == null || v.isEmpty ? l10n.embassyFieldRequiredShort : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: _inputDecoration(l10n.email),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Passport info (conditional)
              if (_requiresPassportInfo(demarche)) ...[
                _buildSectionTitle(l10n.embassyPassportInfo),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passportNumberController,
                        decoration: _inputDecoration(l10n.embassyPassportNumber),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _passportExpiryController,
                        decoration: _inputDecoration(
                          'Date d\'expiration',
                          l10n.embassyDateFormat,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Notes
              _buildSectionTitle(l10n.embassyNotesSection),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: _inputDecoration(
                  '',
                  l10n.embassyNotesPlaceholder,
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
                  label: Text(_isLoading ? l10n.embassySending : l10n.embassySubmitRequest),
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

  /// Préfixe des entrées de dropdown qui servent d'intertitre de rubrique.
  ///
  /// Une valeur sentinelle plutôt que `null` : `DropdownButtonFormField`
  /// exige qu'au plus une entrée porte la valeur sélectionnée, et plusieurs
  /// entrées à `null` déclencheraient l'assertion dès que rien n'est choisi.
  static const String _prefixeEntete = '__rubrique__';

  /// Les 20 démarches groupées sous leurs 5 rubriques.
  ///
  /// Une liste plate serait illisible, et surtout ne dirait pas qu'une
  /// transcription d'acte n'est pas une déclaration. Les intertitres sont des
  /// entrées désactivées : le dropdown du design kit reste utilisé tel quel,
  /// sans brique visuelle parallèle.
  List<DropdownMenuItem<String>> _itemsDemarches(DemarchesCatalogue catalogue) {
    final items = <DropdownMenuItem<String>>[];
    for (final rubrique in catalogue.rubriquesTriees) {
      items.add(
        DropdownMenuItem<String>(
          value: '$_prefixeEntete${rubrique.id}',
          enabled: false,
          child: Text(
            rubrique.titre.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
      for (final demarche in catalogue.parRubrique(rubrique.id)) {
        items.add(
          DropdownMenuItem<String>(
            value: demarche.id,
            child: Text(
              demarche.titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }
    return items;
  }

  void _changerDemarche(String? valeur) {
    // Un intertitre est déjà `enabled: false`, mais on ne s'y fie pas : le
    // garde coûte une comparaison et évite de poser une sentinelle en choix.
    if (valeur == null || valeur.startsWith(_prefixeEntete)) return;
    setState(() {
      _selectedDemarcheId = valeur;
      // Les cases cochées ne valaient que pour la démarche précédente.
      _checkedDocuments.clear();
    });
  }

  /// Tout ce que le catalogue sait de la démarche choisie : résumé, lieu,
  /// délai, coût, défauts connus de la source, pièces, et provenance.
  List<Widget> _detailsDemarche(Demarche? demarche, CatalogueCharge charge) {
    if (demarche == null) return const <Widget>[];
    final blocs = <Widget>[];

    if (demarche.resume != null) {
      blocs.addAll([
        const SizedBox(height: 8),
        Text(
          demarche.resume!,
          style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
        ),
      ]);
    }

    // Le certificat de nationalité ne se traite pas au consulat : le dire
    // avant que l'usager n'ait rempli tout le formulaire.
    if (demarche.lieu == 'tribunal_niger') {
      final juridiction = demarche.juridictionCompetente;
      blocs.addAll([
        const SizedBox(height: 12),
        _encart(
          couleur: Colors.orange,
          texte: [
            "Cette démarche ne se fait pas au consulat : la demande s'adresse "
                'à une juridiction au Niger.',
            if (juridiction != null) juridiction.autorite,
            if (juridiction != null)
              ...juridiction.regles.map((regle) => '• $regle'),
          ].join('\n'),
        ),
      ]);
    }

    blocs.addAll([
      const SizedBox(height: 12),
      // Aucune démarche de la source ne publie de délai. Le dire est plus
      // utile qu'un silence, qui se lirait comme un oubli d'affichage.
      _ligneMeta(
        icone: Icons.schedule,
        texte:
            demarche.delai ??
            'Délai de traitement non communiqué par la source',
        accentue: demarche.delai != null,
      ),
      const SizedBox(height: 6),
      _ligneMeta(
        icone: Icons.payments_outlined,
        texte: demarche.cout.libelleAffichable,
        accentue: demarche.cout.estConnu,
      ),
    ]);

    for (final avertissement in demarche.avertissements) {
      blocs.addAll([
        const SizedBox(height: 10),
        _encart(couleur: Colors.orange, texte: avertissement),
      ]);
    }

    blocs.addAll([
      const SizedBox(height: 24),
      _buildSectionTitle('Pièces à joindre'),
      const SizedBox(height: 2),
      Text(
        '${demarche.nombreDePiecesRequises} à réunir',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      const SizedBox(height: 4),
    ]);

    for (final groupe in demarche.groupesDePieces) {
      blocs.add(
        groupe.length == 1
            ? _casePiece(groupe.first)
            : _groupeAlternatif(groupe),
      );
    }

    for (final conditionnel in demarche.piecesConditionnelles) {
      blocs.addAll([
        const SizedBox(height: 12),
        Text(
          conditionnel.condition,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (conditionnel.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              conditionnel.note!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ...conditionnel.pieces.map(_casePiece),
      ]);
    }

    blocs.addAll([const SizedBox(height: 16), _encartSource(charge)]);
    return blocs;
  }

  Widget _casePiece(DemarchePiece piece) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Text(
        piece.libelleAffichable,
        style: const TextStyle(fontSize: 13.5),
      ),
      subtitle:
          piece.note == null
              ? null
              : Text(
                piece.note!,
                style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
              ),
      value: _checkedDocuments.contains(piece.libelle),
      onChanged: (coche) {
        setState(() {
          if (coche ?? false) {
            _checkedDocuments.add(piece.libelle);
          } else {
            _checkedDocuments.remove(piece.libelle);
          }
        });
      },
    );
  }

  /// Pièces interchangeables : une seule suffit.
  ///
  /// Les afficher comme autant de cases obligatoires ferait croire qu'il faut
  /// les réunir toutes — et masquerait la seule voie ouverte à qui n'a aucun
  /// papier nigérien : deux témoins déjà immatriculés, à la place d'une pièce
  /// d'identité, pour obtenir la carte consulaire.
  Widget _groupeAlternatif(List<DemarchePiece> groupe) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Au choix — une seule de ces pièces suffit',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          for (var i = 0; i < groupe.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'ou',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ),
            _casePiece(groupe[i]),
          ],
        ],
      ),
    );
  }

  Widget _ligneMeta({
    required IconData icone,
    required String texte,
    required bool accentue,
  }) {
    final couleur =
        accentue ? Theme.of(context).colorScheme.primary : Colors.grey[600];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texte,
            style: TextStyle(
              fontSize: 12,
              fontWeight: accentue ? FontWeight.w600 : FontWeight.w400,
              color: couleur,
            ),
          ),
        ),
      ],
    );
  }

  Widget _encart({required MaterialColor couleur, required String texte}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcon.warning, color: couleur[700], size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  /// Provenance et fraîcheur de la liste affichée.
  ///
  /// La source date de 2017 et n'est plus maintenue ; servir ses pièces sans
  /// le dire leur donnerait une autorité qu'elles n'ont pas. L'origine
  /// (serveur, cache, copie embarquée) est signalée pour la même raison :
  /// une liste relue hors ligne peut avoir des mois de retard sur la base.
  Widget _encartSource(CatalogueCharge charge) {
    final source = charge.catalogue.source;
    final origine = switch (charge.origine) {
      OrigineCatalogue.serveur => '',
      OrigineCatalogue.cache => ' · liste enregistrée hors ligne',
      OrigineCatalogue.embarque => " · liste fournie avec l'application",
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Source : ${source.editeur}, consultée le ${source.consulteLe}'
        '$origine.\nCes informations peuvent avoir changé : confirmez-les '
        'auprès de votre consulat avant de vous déplacer.',
        style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.35),
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
