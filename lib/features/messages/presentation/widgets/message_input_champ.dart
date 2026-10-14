part of 'message_input.dart';

/// Champ de saisie : bouton émoji, bouton +, pilule, panneau des pièces
/// jointes.
extension _ChampSaisie on _MessageInputState {
  /// Révèle un panneau **à la place du clavier**, jamais en plus de lui.
  ///
  /// La fraction visible suit le retrait du clavier : pleine hauteur d'inset =
  /// rien d'affiché, inset nul = panneau entier. La hauteur totale de la
  /// colonne reste donc constante pendant toute l'animation, ce qui supprime
  /// l'overflow au lieu de le rendre seulement moins probable.
  ///
  /// Le panneau est aussi borné à la hauteur du clavier : au-delà, il défile.
  Widget _revealInKeyboardSlot(
    BuildContext context,
    Widget child, {
    bool enRecherche = false,
  }) {
    // ⚠ Pas `MediaQuery.of(context).viewInsets` : le `Scaffold` consomme
    // l'inset du clavier pour rétrécir son `body`, donc il vaut déjà 0 ici.
    // Seule la vue porte encore la vraie hauteur du clavier.
    final view = View.of(context);
    final insets = view.viewInsets.bottom / view.devicePixelRatio;
    if (insets > _lastKeyboardHeight) {
      _lastKeyboardHeight = insets;
    }
    // Repli tant qu'aucun clavier n'a encore été vu (premier ouverture au « + »
    // sans avoir tapé) : hauteur usuelle d'un clavier Android.
    final slot = _lastKeyboardHeight > 0 ? _lastKeyboardHeight : 280.0;
    // En recherche, le clavier est là POUR le panneau : on ne se replie pas
    // devant lui. Même arbre (ClipRect → Align → ConstrainedBox) dans les deux
    // cas, pour que le panneau garde son état — onglet, texte saisi.
    final factor =
        enRecherche ? 1.0 : ((slot - insets) / slot).clamp(0.0, 1.0);
    final hauteurMax =
        enRecherche && slot > _hauteurPanneauEnRecherche
            ? _hauteurPanneauEnRecherche
            : slot;

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: factor,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: hauteurMax),
          child: child,
        ),
      ),
    );
  }

  /// Emoji en pastille propre, à droite de la barre (fiche 26b : cercle 44,
  /// fond `#F7EAE3`, glyphe `#FA7D00`). Il bascule en icône clavier quand le
  /// panneau est ouvert, comme lorsqu'il vivait dans le champ.
  ///
  /// Les valeurs de la fiche sont la version claire : en nocturne l'aplat
  /// pastel deviendrait un pavé lumineux, on le remplace par l'accent teinté.
  Widget _buildEmojiButton(BuildContext context) {
    final isDark = context.isDarkMode;
    final glyph = isDark ? const Color(0xFFFA7E3B) : const Color(0xFFFA7D00);
    final fill =
        isDark
            ? glyph.withValues(alpha: _showPicker ? 0.28 : 0.18)
            : (_showPicker ? const Color(0xFFF0DAC8) : const Color(0xFFF7EAE3));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      // 40 plutôt que 44 : la pastille vit maintenant dans la pilule, elle doit
      // tenir dans sa hauteur de ligne sans la faire grossir.
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: IconButton(
        onPressed: () => _togglePicker(),
        icon: Icon(
          _showPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
          size: 23,
        ),
        tooltip: AppLocalizations.of(context)!.emojis,
        color: glyph,
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Bouton « + » hors du champ : ouvre le panneau ancré (grille 3×2).
  /// Pastille circulaire teintée accent (le « + » pivote en « × » à l'ouverture).
  /// Appui long = ancien sheet complet (repli avec audio/vidéo dédiés).
  Widget _buildPlusButton(BuildContext context) {
    final active = _showAttachPanel;
    final accent = context.adaptivePrimaryColor;
    final isDark = context.isDarkMode;

    // En clair, l'accent à 12 % posé sur le fond crème de la page donnait deux
    // teintes quasi identiques (relevé à l'écran : #F2E5D9 des deux côtés) —
    // le disque disparaissait, seul le glyphe orange se voyait. Il reprend donc
    // la surface de la pilule, blanc + liseré, et devient un frère de la barre
    // au lieu d'une tache. En nocturne l'aplat teinté ressort déjà sur le fond
    // sombre : on n'y touche pas.
    final poseSurLaPage = !isDark && !active;
    final fill =
        active
            ? accent.withValues(alpha: isDark ? 0.20 : 0.22)
            : (isDark ? accent.withValues(alpha: 0.12) : _kBarFillLight);

    return GestureDetector(
      onLongPress: _showAttachmentOptions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        // 40 : le « + » est secondaire, seul le bouton d'envoi garde 44.
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border:
              poseSurLaPage
                  ? Border.all(color: _kBarBorderLight, width: 1)
                  : null,
          boxShadow:
              poseSurLaPage
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: IconButton(
          onPressed: _toggleAttachPanel,
          // Le même glyphe « + » pivote de 45° pour devenir une croix.
          icon: AnimatedRotation(
            turns: active ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: const Icon(Icons.add_rounded, size: 24),
          ),
          tooltip: AppLocalizations.of(context)!.sendFileTitle,
          color: accent,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  /// Champ pilule. L'emoji n'y est plus : il a rejoint sa propre pastille,
  /// hors de la barre (fiche 26b).
  /// [borne] : hauteur disponible pour tout le composer, `infinity` si
  /// personne ne nous en a donné une.
  Widget _buildPillField(BuildContext context, double borne) {
    // Six lignes, c'est bon en portrait (873 dp). En paysage il ne reste que
    // ~190 dp sous les bandeaux : un champ de six lignes y mangerait tout et
    // ferait déborder la colonne avant même que le panneau s'ouvre. On lui
    // laisse au plus la moitié de la place, ~22 dp par ligne.
    final maxLignes = borne.isFinite ? (borne / 2 / 22).floor().clamp(1, 6) : 6;
    // Dernier point de compression du plancher paysage (cf. `_buildColumn`) :
    // desserre aussi le padding vertical interne du champ lui-même.
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // Aucun cadre ni fond : la saisie se fond dans la barre flottante.
          constraints: BoxConstraints(minHeight: isLandscape ? 38 : 44),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !widget.isLoading,
                  // La barre grandit avec le texte jusqu'à 6 lignes, puis le
                  // champ défile verticalement. `maxLines: 6` plutôt qu'une
                  // contrainte de hauteur sur le Container : avec `null`, le
                  // champ déborde au lieu de défiler.
                  minLines: 1,
                  maxLines: maxLignes,
                  keyboardType: TextInputType.multiline,
                  // Entrée insère un retour à la ligne ; l'envoi passe par le
                  // bouton rond, toujours présent à droite.
                  textInputAction: TextInputAction.newline,
                  maxLength: _maxCharCount,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: context.textPrimaryColor,
                  ),
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.yourMessage,
                    hintStyle: TextStyle(
                      color: context.textTertiaryColor,
                      fontSize: 15.5,
                    ),
                    isCollapsed: true,
                    // Le thème global impose un OutlineInputBorder : on neutralise
                    // TOUS les états (sinon le cadre reste malgré `border: none`).
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    // Seul le « + » est hors de la pilule : 10 + les 8 du
                    // Container = 18 réels à gauche. À droite, la pastille
                    // emoji fait office de marge, d'où le 4.
                    contentPadding: EdgeInsets.only(
                      left: 10,
                      right: 4,
                      top: isLandscape ? 9 : 12,
                      bottom: isLandscape ? 9 : 12,
                    ),
                  ),
                ),
              ),
              // Pastille emoji dans la pilule, collée en bas à droite : elle
              // reste entièrement à droite du champ (elle n'empiète pas
              // dessus), mais ne coûte plus 52 dp de largeur au texte.
              _buildEmojiButton(context),
            ],
          ),
        ),
        // Le compteur ne reconstruit que lui-même à la frappe : la colonne du
        // composer, elle, ne bouge qu'au franchissement du seuil.
        if (_showCounter)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => _buildCharacterCounter(context),
          ),
      ],
    );
  }

  /// Panneau ancré (grille 3×2) : Caméra, Galerie, Document, Position,
  /// Sondage, Événement.
  Widget _buildAttachPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = <Widget>[
      _buildAttachTile(
        icon: Icons.photo_camera,
        label: l10n.cameraSection,
        color: AttachmentAccents.camera.of(context),
        onTap: () {
          _toggleAttachPanel();
          unawaited(_openCamera());
        },
      ),
      _buildAttachTile(
        icon: Icons.photo_library,
        label: l10n.photosLabel,
        color: AttachmentAccents.gallery.of(context),
        onTap: () {
          _toggleAttachPanel();
          unawaited(_pickFromGalleryUnified());
        },
      ),
      _buildAttachTile(
        icon: Icons.description,
        label: l10n.documentsLabel,
        color: AttachmentAccents.document.of(context),
        onTap: () {
          _toggleAttachPanel();
          unawaited(_pickFile());
        },
      ),
      if (widget.onSendLocation != null)
        _buildAttachTile(
          icon: Icons.location_on,
          label: l10n.positionLabel,
          color: AttachmentAccents.location.of(context),
          onTap: () {
            _toggleAttachPanel();
            unawaited(_showLocationPicker());
          },
        ),
      if (widget.onCreatePoll != null)
        _buildAttachTile(
          icon: Icons.poll,
          label: l10n.pollLabel,
          color: AttachmentAccents.poll.of(context),
          onTap: () {
            _toggleAttachPanel();
            widget.onCreatePoll!();
          },
        ),
      if (widget.onCreateEvent != null)
        _buildAttachTile(
          icon: Icons.event,
          label: l10n.eventLabel,
          color: AttachmentAccents.event.of(context),
          onTap: () {
            _toggleAttachPanel();
            widget.onCreateEvent!();
          },
        ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border:
            context.isDarkMode ? Border.all(color: AppColors.borderDark) : null,
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        // Défilable : le panneau est borné au créneau du clavier, et sur un
        // petit écran (ou en paysage) la grille doit pouvoir glisser au lieu
        // de déborder.
        physics: const ClampingScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: tiles,
      ),
    );
  }

  Widget _buildAttachTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

