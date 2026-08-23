import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionCandidate;

class MentionSuggestionOverlay extends StatelessWidget {
  final List<MentionCandidate> suggestions;
  final void Function(MentionCandidate) onSelect;

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
            final candidate = suggestions[index];
            final token = candidate.mentionToken;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: context.adaptivePrimaryColor.withValues(alpha: 0.15),
                child: Text(
                  candidate.displayName.isNotEmpty
                      ? candidate.displayName[0].toUpperCase()
                      : '@',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
              ),
              // Le nom se lit, le pseudo s'écrit : la ligne montre les deux,
              // sinon on choisit un `@` sans savoir à qui il correspond.
              title: Text(
                candidate.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '@$token',
                style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelect(candidate),
            );
          },
        ),
      ),
    );
  }
}
