import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../features/profile/data/datasources/profile_supabase_datasource.dart';
import '../../domain/entities/post_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Returns a `\w+`-compatible handle from a display name.
String _toMentionHandle(String displayName) =>
    displayName.replaceAll(RegExp(r'[^\w]'), '');

/// Extracts all #hashtags from text as lowercase strings.
List<String> extractHashtags(String text) => RegExp(r'#(\w+)')
    .allMatches(text)
    .map((m) => m.group(1)!.toLowerCase())
    .toList();

enum _SuggestionType { user, group, countryGroup }

/// Countries relevant to the diaspora community.
const _knownCountries = <String, String>{
  'Niger': 'Niger',
  'France': 'France',
  'Algerie': 'Algérie',
  'Maroc': 'Maroc',
  'Mali': 'Mali',
  'Burkina': 'Burkina Faso',
  'BurkinaFaso': 'Burkina Faso',
  'Nigeria': 'Nigeria',
  'Senegal': 'Sénégal',
  'Canada': 'Canada',
  'USA': 'USA',
  'Allemagne': 'Allemagne',
  'Belgique': 'Belgique',
  'Italie': 'Italie',
  'Espagne': 'Espagne',
};

const _countryLabels = <String, String>{
  'Niger': 'Amis au Niger',
  'France': 'Amis en France',
  'Algerie': 'Amis en Algérie',
  'Maroc': 'Amis au Maroc',
  'Mali': 'Amis au Mali',
  'Burkina': 'Amis au Burkina Faso',
  'BurkinaFaso': 'Amis au Burkina Faso',
  'Nigeria': 'Amis au Nigeria',
  'Senegal': 'Amis au Sénégal',
  'Canada': 'Amis au Canada',
  'USA': 'Amis aux USA',
  'Allemagne': 'Amis en Allemagne',
  'Belgique': 'Amis en Belgique',
  'Italie': 'Amis en Italie',
  'Espagne': 'Amis en Espagne',
};

Map<String, String> _matchCountries(String query) {
  final q = query.toLowerCase();
  return Map.fromEntries(
    _knownCountries.entries.where(
      (e) => e.key.toLowerCase().startsWith(q),
    ),
  );
}

class _Suggestion {
  final _SuggestionType type;
  final String id;
  final String displayName;
  final String? label;
  final String? photoUrl;
  final List<String> memberIds;
  final bool isPrivate;

  const _Suggestion({
    required this.type,
    required this.id,
    required this.displayName,
    this.label,
    this.photoUrl,
    this.memberIds = const [],
    this.isPrivate = false,
  });
}

class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final InputDecoration? decoration;
  final void Function(
    List<MentionedUser> users,
    List<MentionedGroup> groups,
    List<String> hashtags,
  )? onTagsChanged;

  const MentionTextField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.maxLines,
    this.textCapitalization = TextCapitalization.sentences,
    this.style,
    this.decoration,
    this.onTagsChanged,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final _profileDataSource = ProfileSupabaseDataSource();

  String? _activeMentionQuery;
  List<_Suggestion> _suggestions = [];
  bool _isSearching = false;

  final Map<String, MentionedUser> _confirmedUsers = {};
  final Map<String, MentionedGroup> _confirmedGroups = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    if (!sel.isValid || sel.baseOffset < 0) return;

    final offset = sel.baseOffset.clamp(0, text.length);
    final textBefore = text.substring(0, offset);
    final mentionMatch = RegExp(r'@(\w*)$').firstMatch(textBefore);

    if (mentionMatch != null) {
      final query = mentionMatch.group(1)!;
      if (query != _activeMentionQuery) {
        setState(() => _activeMentionQuery = query);
        _search(query);
      }
      _notifyTags();
      return;
    }

    if (_activeMentionQuery != null) {
      setState(() {
        _activeMentionQuery = null;
        _suggestions = [];
      });
    }
    _notifyTags();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);

    final results = await Future.wait([
      _searchUsers(query),
      _searchGroups(query),
      _searchFriendsByCountry(query),
    ]);

    if (mounted && _activeMentionQuery == query) {
      setState(() {
        _suggestions = [...results[2], ...results[0], ...results[1]];
        _isSearching = false;
      });
    }
  }

  Future<List<_Suggestion>> _searchFriendsByCountry(String query) async {
    if (query.length < 2) return [];
    final matches = _matchCountries(query);
    if (matches.isEmpty) return [];

    final suggestions = <_Suggestion>[];
    for (final entry in matches.entries.take(2)) {
      try {
        final profiles =
            await _profileDataSource.getProfilesByCountry(entry.value);
        if (profiles.isEmpty) continue;
        final memberIds = profiles.map((p) => p.id).toList();
        suggestions.add(
          _Suggestion(
            type: _SuggestionType.countryGroup,
            id: 'country_${entry.key}',
            displayName: 'Amis${entry.key}',
            label: _countryLabels[entry.key],
            memberIds: memberIds,
          ),
        );
      } catch (_) {}
    }
    return suggestions;
  }

  Future<List<_Suggestion>> _searchUsers(String query) async {
    try {
      final profiles = await _profileDataSource.searchProfiles(query);
      return profiles.take(4).map((p) {
        final name = p.displayName ?? p.email ?? 'Utilisateur';
        return _Suggestion(
          type: _SuggestionType.user,
          id: p.id,
          displayName: name,
          photoUrl: p.photoUrl,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<_Suggestion>> _searchGroups(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      final rows = await Supabase.instance.client
          .from('groups')
          .select('id, name, image_url, member_ids')
          .eq('is_private', false)
          .ilike('name', '$lowerQuery%')
          .limit(4);

      return rows.map((row) {
        return _Suggestion(
          type: _SuggestionType.group,
          id: row['id'] as String,
          displayName: row['name'] as String? ?? '',
          photoUrl: row['image_url'] as String?,
          memberIds: List<String>.from(row['member_ids'] as List? ?? []),
          isPrivate: false,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _selectSuggestion(_Suggestion s) {
    final handle = _toMentionHandle(s.displayName);
    final text = widget.controller.text;
    final offset = widget.controller.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, offset);
    final after = text.substring(offset);
    final newBefore = before.replaceAll(RegExp(r'@\w*$'), '@$handle ');
    final newText = newBefore + after;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );

    if (s.type == _SuggestionType.user) {
      _confirmedUsers[handle] = MentionedUser(id: s.id, name: handle);
    } else {
      _confirmedGroups[handle] = MentionedGroup(
        id: s.id,
        name: handle,
        memberIds: s.memberIds,
      );
    }

    setState(() {
      _activeMentionQuery = null;
      _suggestions = [];
    });
    _notifyTags();
  }

  void _notifyTags() {
    if (widget.onTagsChanged == null) return;
    final text = widget.controller.text;

    final activeUsers = _confirmedUsers.entries
        .where((e) => text.contains('@${e.key}'))
        .map((e) => e.value)
        .toList();

    final activeGroups = _confirmedGroups.entries
        .where((e) => text.contains('@${e.key}'))
        .map((e) => e.value)
        .toList();

    widget.onTagsChanged!(activeUsers, activeGroups, extractHashtags(text));
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions =
        _activeMentionQuery != null && _activeMentionQuery!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSuggestions)
          _SuggestionList(
            suggestions: _suggestions,
            isLoading: _isSearching,
            onSelect: _selectSuggestion,
          ),
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          textCapitalization: widget.textCapitalization,
          style: widget.style,
          decoration: widget.decoration ??
              InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
              ),
        ),
      ],
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<_Suggestion> suggestions;
  final bool isLoading;
  final void Function(_Suggestion) onSelect;

  const _SuggestionList({
    required this.suggestions,
    required this.isLoading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isLoading && suggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : suggestions.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final s = suggestions[index];
                    final isGroup = s.type == _SuggestionType.group;
                    final isCountryGroup =
                        s.type == _SuggestionType.countryGroup;

                    return InkWell(
                      onTap: () => onSelect(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isCountryGroup
                                  ? Colors.orange.shade100
                                  : null,
                              backgroundImage: s.photoUrl != null
                                  ? NetworkImage(s.photoUrl!)
                                  : null,
                              child: s.photoUrl == null
                                  ? AppIcon(
                                      isCountryGroup
                                          ? AppIcon.public
                                          : isGroup
                                              ? AppIcon.groups
                                              : AppIcon.person,
                                      size: 16,
                                      color: isCountryGroup
                                          ? Colors.orange
                                          : null,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s.label ?? '@${s.displayName}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isCountryGroup
                                          ? FontWeight.w600
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isCountryGroup)
                                    Text(
                                      '${s.memberIds.length} ami(s) • Mentionner ce groupe',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.orange.shade700),
                                    ),
                                ],
                              ),
                            ),
                            if (isGroup)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Groupe',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
