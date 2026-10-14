part of 'conversation_screen.dart';

/// Barre d'application, état vide, bandeau des demandes de message.
extension _BarreConversation on _ConversationScreenState {
  PreferredSizeWidget _buildAppBar(
    dynamic otherUser,
    dynamic groupData,
    ConversationEntity? conversation,
    bool isDeleted,
    bool identityLoading,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // For groups: use passed name, fallback to loaded group data, then default
    // For individual: use loaded user profile, fallback to passed name, then default
    //
    // `conversation?.name` s'intercale avant `groupData` : la conversation
    // porte déjà le nom du groupe (colonne `data->>'name'`), alors que
    // `groupData` vient de `groupStreamProvider`, encore câblé sur FIRESTORE
    // (`GroupRemoteDataSourceImpl`) — il rend donc null pour tout groupe créé
    // dans Supabase, et l'en-tête retombait sur « Groupe » quand aucun
    // `state.extra` n'était fourni (lien profond, notification). Vérifié sur
    // appareil le 2026-08-05 : « Diaspora Niger — Canada » s'affichait
    // « Groupe », alors que la liste des messages — qui lit `conversation.name`
    // — montrait le bon nom.
    //
    // `isDeleted` prime sur tout le reste : une conversation dont le flux a
    // livré `null` (supprimée, ou notification pointant vers un id détruit
    // par la purge du 2026-08-14 — voir
    // project_messages_conversations_purge_2026_08_14) n'a plus de nom à
    // dériver nulle part. Sans ce garde, l'en-tête retombait sur le
    // générique « Utilisateur », qui se lisait comme un blocage plutôt que
    // comme une conversation supprimée.
    //
    // `identityLoading` prime sur le repli `l10n.user` : ce dernier ne doit
    // dire « Utilisateur » qu'une fois l'attente terminée et le profil
    // effectivement introuvable, jamais pendant les deux allers-retours
    // encore en vol (conversation, puis profil de l'autre participant).
    final displayName =
        isDeleted
            ? (_isGroup ? l10n.thisGroupWasDeleted : l10n.conversationDeleted)
            : identityLoading
            ? (widget.conversationName ?? l10n.loading)
            : _isSelfNotes
            ? l10n.messagesMyNotes
            : _isGroup
            ? (widget.conversationName ??
                conversation?.name ??
                groupData?.name ??
                l10n.group)
            : (otherUser?.displayName ?? widget.conversationName ?? l10n.user);

    final displayImage =
        _isSelfNotes
            ? null
            : _isGroup
            ? (widget.conversationImageUrl ??
                conversation?.imageUrl ??
                groupData?.imageUrl)
            : (otherUser?.photoUrl ?? widget.conversationImageUrl);

    final initials = _getInitials(displayName);

    // Check if user is deleted
    final isDeletedUser =
        otherUser != null && otherUser.displayName == DeletedAccount.storedName;

    return AppBar(
      backgroundColor: context.surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 58,
      leadingWidth: 40,
      leading: IconButton(
        padding: EdgeInsets.zero,
        onPressed: _leaveConversation,
        icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
      ),
      title: InkWell(
        onTap: () async {
          // debugPrint('🔘 Tapped conversation header:');
          // debugPrint('   isGroup: ${_isGroup}');
          // debugPrint('   groupId: ${_effectiveGroupId}');
          // debugPrint('   otherUserId: ${_effectiveOtherUserId}');

          if (_isGroup) {
            // Use passed groupId, fallback to loaded groupData, then search by name
            String? groupIdToUse = _effectiveGroupId ?? groupData?.id;

            if (groupIdToUse == null && widget.conversationName != null) {
              final group = await ref.read(
                groupByNameProvider(widget.conversationName!).future,
              );
              groupIdToUse = group?.id;
            }

            if (!mounted) return;
            if (groupIdToUse != null) {
              unawaited(context.push('/groups/$groupIdToUse'));
            } else {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.loadingError)));
            }
          } else if (_effectiveOtherUserId != null) {
            if (isDeletedUser) {
              return;
            }
            // debugPrint('   ➡️ Navigating to /profile/${_effectiveOtherUserId}');
            unawaited(context.push('/profile/$_effectiveOtherUserId'));
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Avatar + pastille de présence (fiche 4a). La pastille manquait :
              // l'en-tête ne disait « En ligne » qu'en toutes lettres, sous le
              // nom, là où la maquette la pose sur l'avatar.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      // Aplat, plus de dégradé : vert pour un groupe, terracotta
                      // pour une personne (§3b, §3c).
                      color:
                          _isGroup
                              ? context.adaptiveSecondaryColor
                              : context.adaptivePrimaryColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child:
                        displayImage != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: CachedNetworkImage(
                                imageUrl: displayImage,
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, __) => Center(
                                      child:
                                          _isGroup
                                              ? const AppIcon(
                                                AppIcon.groups,
                                                color: AppColors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                    ),
                                errorWidget:
                                    (_, __, ___) => Center(
                                      child:
                                          _isGroup
                                              ? const AppIcon(
                                                AppIcon.groups,
                                                color: AppColors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                    ),
                              ),
                            )
                            : Center(
                              child:
                                  _isSelfNotes
                                      ? const Icon(
                                        Icons.bookmark_rounded,
                                        color: AppColors.white,
                                        size: 22,
                                      )
                                      : _isGroup
                                      ? const AppIcon(
                                        AppIcon.groups,
                                        color: AppColors.white,
                                        size: 20,
                                      )
                                      : Text(
                                        initials,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                  ),
                  if (!_isGroup &&
                      _effectiveOtherUserId != null &&
                      !isDeletedUser)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      // Le liseré reprend le fond de l'en-tête : la pastille
                      // doit se détacher de l'avatar, pas s'y fondre.
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          shape: BoxShape.circle,
                        ),
                        child: OnlineStatusIndicator(
                          userId: _effectiveOtherUserId!,
                          showText: false,
                          dotSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom de la conversation, en serif comme tous les
                    // titres de la série (§3b, §4a).
                    DesignSectionTitle(
                      displayName ?? AppLocalizations.of(context)!.conversation,
                      size: 17,
                    ),
                    // Status text below name + cadenas chiffrement (§4a) —
                    // jamais affiché pour un compte supprimé, rien à protéger.
                    if (_isSelfNotes)
                      _buildStatusWithLock(
                        Text(
                          'Notes personnelles',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      )
                    else if (_isGroup)
                      Builder(
                        builder: (_) {
                          final count = groupData?.memberCount as int?;
                          final label =
                              (count != null && count > 0)
                                  ? '$count ${count > 1 ? 'membres' : 'membre'}'
                                  : AppLocalizations.of(context)!.group;
                          return _buildStatusWithLock(
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiaryColor,
                              ),
                            ),
                          );
                        },
                      )
                    else if (!_isGroup &&
                        _effectiveOtherUserId != null &&
                        !isDeletedUser)
                      // Online status text for individual chats
                      _buildStatusWithLock(
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: OnlineStatusIndicator(
                            key: ValueKey(_effectiveOtherUserId),
                            userId: _effectiveOtherUserId!,
                            showText: true,
                            showDot: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Appels 1-à-1 mis en pause (fiabilité en cours de vérification sur
        // appareil réel — 2026-08-14) : boutons masqués, code conservé pour
        // réactivation. Voir TESTS_APPAREIL_A_FAIRE.md.
        // TODO(appels): réactiver après vérification à deux vrais téléphones.
        // if (!_isGroup && !isDeletedUser && !_isSelfNotes) ...[
        //   IconButton(
        //     onPressed: () => _startCall(isVideo: false),
        //     icon: AppIcon(
        //       AppIcon.call,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.voiceCall,
        //   ),
        //   IconButton(
        //     onPressed: () => _startCall(isVideo: true),
        //     icon: AppIcon(
        //       AppIcon.video,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.videoCall,
        //   ),
        // ],
        // Appels de GROUPE mis en pause le 2026-09-14, comme le 1-à-1 avant
        // eux : sous 5 participants un appel de groupe tourne en maillage
        // flutter_webrtc — le MÊME `webrtc_service.dart` que le 1-à-1, et
        // non LiveKit (qui ne prend le relais qu'en SFU, à 5 participants
        // et plus). Les laisser actifs laissait la pile non vérifiée
        // atteignable depuis n'importe quel groupe. Boutons masqués, code
        // conservé. Voir TESTS_APPAREIL_A_FAIRE.md.
        // TODO(appels): réactiver après vérification à deux vrais téléphones.
        // if (_isGroup && !_isSelfNotes) ...[
        //   IconButton(
        //     onPressed: () => _startGroupCall(isVideo: false),
        //     icon: AppIcon(
        //       AppIcon.call,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.voiceCall,
        //   ),
        //   IconButton(
        //     onPressed: () => _startGroupCall(isVideo: true),
        //     icon: AppIcon(
        //       AppIcon.video,
        //       size: 21,
        //       color: context.textPrimaryColor,
        //     ),
        //     tooltip: l10n.videoCall,
        //   ),
        // ],
        // More options button — icône nue, sans conteneur gris (§4a).
        IconButton(
          onPressed: () => _showConversationOptions(),
          icon: Icon(
            Icons.more_vert,
            color: context.textPrimaryColor,
            size: 21,
          ),
        ),
      ],
    );
  }

  /// Statut + cadenas chiffrement (§4a) : Signal pour 1-à-1/groupes, AES
  /// local pour « Mes notes » — jamais affiché pour un compte supprimé
  /// (géré en amont, cette méthode n'est pas appelée dans ce cas).
  ///
  /// ⚠️ Ce cadenas ne dit PAS le niveau de chiffrement réel. Un groupe peut
  /// tourner en repli AES — le cadenas reste le même. L'indicateur qui le
  /// signalait (cadenas ouvert + libellé + feuille explicative) a été retiré
  /// le 2026-08-23 à la demande de Salim.
  ///
  /// L'état reste mesuré et disponible dans `groupEncryptionStatusProvider`,
  /// et les journaux de `SenderKeyService` disent « repli AES maintenu » avec
  /// le compte de membres servis : c'est par là qu'il faut passer pour savoir
  /// où en est un groupe.
  Widget _buildStatusWithLock(Widget status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: status),
        const SizedBox(width: 4),
        AppIcon(AppIcon.lock, size: 11, color: context.textTertiaryColor),
      ],
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    // Scrollable : en paysage (ou clavier ouvert) la hauteur restante tombe
    // sous les ~317 px de l'illustration + textes → RenderFlex overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated chat illustration
            Container(
              width: 120,
              height: 120,
              // Pastille plate : le système n'utilise plus de dégradé
              // décoratif, l'illustration d'état vide est un aplat teinté.
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AppIcon(
                    AppIcon.chatBubble,
                    size: 48,
                    color: context.adaptivePrimaryColor,
                  ),
                  // Small decorative elements
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.adaptiveSecondaryColor.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 25,
                    left: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.noMessages,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isGroup ? l10n.sendFirstMessageGroup : l10n.sendFirstMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Subtle hint with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: context.textTertiaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.typeYourMessageBelow,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRequestBanner(
    AppLocalizations l10n,
    ConversationEntity conversation,
    String currentUserId,
  ) {
    final isRecipient = conversation.isRequestRecipient(currentUserId);

    if (isRecipient) {
      // Show accept/decline banner for recipient
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: context.adaptivePrimaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.wantsToMessageYou,
                    style: TextStyle(
                      color: context.adaptivePrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleDeclineRequest(conversation.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(l10n.declineRequest),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptRequest(conversation.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.acceptRequest),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Sender sees nothing special - conversation looks normal
    return const SizedBox.shrink();
  }

  Future<void> _handleAcceptRequest(String conversationId) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(messageRequestActionsProvider.notifier);
    final success = await notifier.acceptRequest(conversationId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.requestAccepted)));
        // Refresh conversation
        ref.invalidate(conversationStreamProvider(conversationId));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeclineRequest(String conversationId) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(messageRequestActionsProvider.notifier);
    final success = await notifier.declineRequest(conversationId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.requestDeclined)));
        // Go back after declining (repli si la route est seule dans la pile)
        _leaveConversation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

