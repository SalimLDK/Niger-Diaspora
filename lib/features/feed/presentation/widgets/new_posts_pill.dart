import 'package:flutter/material.dart';

import '../../domain/entities/post_entity.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import 'feed_avatar.dart';

/// Pastille « N nouvelles publications », posée au-dessus du fil.
///
/// Elle flotte sur la liste sans rien pousser : la position de lecture ne
/// bouge pas, c'est l'utilisateur qui décide de remonter. Les avatars des
/// auteurs disent d'un coup d'œil de qui vient le nouveau, comme sur X.
class NewPostsPill extends StatefulWidget {
  const NewPostsPill({
    super.key,
    required this.posts,
    required this.label,
    required this.onTap,
  });

  /// Publications en attente. Vide = pastille masquée.
  final List<PostEntity> posts;

  /// Texte déjà pluralisé (`l10n.feedNewPostsPill`).
  final String label;

  final VoidCallback onTap;

  @override
  State<NewPostsPill> createState() => _NewPostsPillState();
}

class _NewPostsPillState extends State<NewPostsPill> {
  /// Nombre d'avatars empilés avant de s'arrêter.
  static const _maxAvatars = 3;

  /// Dernier contenu non vide, gardé pour dessiner la pastille pendant
  /// qu'elle s'efface : sans lui elle se viderait de son texte avant de
  /// disparaître, ce qui se lit comme un clignotement.
  List<PostEntity> _derniers = const [];
  String _dernierLabel = '';

  @override
  void initState() {
    super.initState();
    _memorise();
  }

  @override
  void didUpdateWidget(NewPostsPill old) {
    super.didUpdateWidget(old);
    _memorise();
  }

  void _memorise() {
    if (widget.posts.isNotEmpty) {
      _derniers = widget.posts;
      _dernierLabel = widget.label;
    }
  }

  /// Un avatar par auteur distinct, dans l'ordre d'arrivée (le plus récent
  /// en tête) : trois publications du même compte n'empilent pas trois fois
  /// la même tête.
  List<PostEntity> _auteursDistincts() {
    final vus = <String>{};
    final result = <PostEntity>[];
    for (final p in _derniers) {
      if (vus.add(p.authorId)) result.add(p);
      if (result.length == _maxAvatars) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    final visible = widget.posts.isNotEmpty;
    final auteurs = _auteursDistincts();

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.8),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Material(
            color: tokens.accent,
            shape: const StadiumBorder(),
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (auteurs.isNotEmpty) ...[
                      _PileAvatars(auteurs: auteurs, tokens: tokens),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: tokens.onAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _dernierLabel,
                      style: FeedText.body(
                        tokens,
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: tokens.onAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatars qui se chevauchent, cerclés de la couleur de la pastille pour
/// rester lisibles l'un sur l'autre.
class _PileAvatars extends StatelessWidget {
  const _PileAvatars({required this.auteurs, required this.tokens});

  final List<PostEntity> auteurs;
  final FeedTokens tokens;

  static const _taille = 22.0;
  static const _chevauchement = 8.0;
  static const _cercle = 1.5;

  @override
  Widget build(BuildContext context) {
    final pas = _taille - _chevauchement;
    return SizedBox(
      width: _taille + (auteurs.length - 1) * pas,
      height: _taille,
      child: Stack(
        children: [
          for (var i = 0; i < auteurs.length; i++)
            Positioned(
              left: i * pas,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.accent, width: _cercle),
                ),
                child: FeedAvatar(
                  name: auteurs[i].authorName,
                  photoUrl: auteurs[i].authorPhotoUrl,
                  tokens: tokens,
                  radius: _taille / 2 - _cercle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
