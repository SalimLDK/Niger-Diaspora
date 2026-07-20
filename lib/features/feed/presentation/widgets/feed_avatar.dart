import 'package:flutter/material.dart';

import '../theme/feed_tokens.dart';

/// Avatar used across the Feed feature: a photo, or a colored circle with
/// the author's initial, using `tokens.avatarBg`/`tokens.avatarFg`.
class FeedAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final FeedTokens tokens;

  const FeedAvatar({
    super.key,
    required this.name,
    required this.tokens,
    this.photoUrl,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: tokens.avatarBg,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: tokens.avatarFg,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.75,
              ),
            ),
    );
  }
}
