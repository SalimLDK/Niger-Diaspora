import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;

class MentionSuggestionOverlay extends StatelessWidget {
  final List<MentionedUser> suggestions;
  final void Function(MentionedUser) onSelect;

  const MentionSuggestionOverlay({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      color: context.surfaceColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: context.isDarkMode
                ? Colors.white10
                : Colors.black12,
          ),
          itemBuilder: (context, index) {
            final user = suggestions[index];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: context.adaptivePrimaryColor.withValues(alpha: 0.15),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '@',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
              ),
              title: Text(
                '@${user.name}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onTap: () => onSelect(user),
            );
          },
        ),
      ),
    );
  }
}
