import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../profile/data/datasources/profile_supabase_datasource.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/story_entity.dart';
import '../providers/story_provider.dart';
import '../story_creation.dart';

/// « Qui peut voir mes stories » : audience par défaut, liste restreinte
/// (« whitelist ») et personnes masquées (« blacklist »).
///
/// Rien de tout ça n'existait : une story partait visible par tous les
/// membres, sans exception possible (signalé le 2026-09-12). Les listes
/// vivent en base (`story_audience_members`) et c'est la base qui les
/// applique (`peut_voir_story`) — l'app ne fait que les montrer.
class StoryPrivacyScreen extends ConsumerWidget {
  const StoryPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audience = ref.watch(storyDefaultAudienceProvider);
    final membersAsync = ref.watch(storyListMembersProvider);
    final members = membersAsync.valueOrNull ?? const <StoryListMember>[];
    final close = members.where((m) => m.kind == StoryListKind.close).toList();
    final hidden = members.where((m) => m.kind == StoryListKind.hidden).toList();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const DesignScreenHeader(
              title: 'Mes stories',
              leading: DesignBackLeading(fallbackRoute: '/feed'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  const DesignSectionLabel('AUDIENCE PAR DÉFAUT'),
                  DesignSettingsCard(
                    children: [
                      DesignSettingsTile(
                        icon: Icon(storyAudienceIcon(audience)),
                        title: audience.label,
                        subtitle: 'Proposée à chaque nouvelle story. '
                            'Chaque story garde celle choisie à sa publication.',
                        onTap: () async {
                          final picked = await showStoryAudienceSheet(
                            context,
                            current: audience,
                            showManageLink: false,
                          );
                          if (picked != null) {
                            await ref
                                .read(storyDefaultAudienceProvider.notifier)
                                .set(picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (membersAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Impossible de charger vos listes.',
                        style: TextStyle(color: context.errorColor),
                      ),
                    ),
                  _ListSection(
                    label: 'LISTE RESTREINTE',
                    explication:
                        'Les seules personnes qui voient une story publiée '
                        'pour « Liste restreinte ».',
                    kind: StoryListKind.close,
                    members: close,
                    loading: membersAsync.isLoading && members.isEmpty,
                  ),
                  const SizedBox(height: 8),
                  _ListSection(
                    label: 'MASQUER MES STORIES À',
                    explication:
                        'Ces personnes ne voient aucune de vos stories, quelle '
                        "que soit l'audience — même « Tout le monde ». Elles "
                        "n'en sont pas averties.",
                    kind: StoryListKind.hidden,
                    members: hidden,
                    loading: membersAsync.isLoading && members.isEmpty,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSection extends ConsumerWidget {
  final String label;
  final String explication;
  final StoryListKind kind;
  final List<StoryListMember> members;
  final bool loading;

  const _ListSection({
    required this.label,
    required this.explication,
    required this.kind,
    required this.members,
    required this.loading,
  });

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final picked = await showModalBottomSheet<_Person>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PersonPicker(
        exclude: members.map((m) => m.memberId).toSet(),
      ),
    );
    if (picked == null) return;
    final echec = await container
        .read(storyActionsNotifierProvider.notifier)
        .setListMember(picked.id, kind);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          echec ??
              (kind == StoryListKind.close
                  ? '${picked.name} ajouté(e) à la liste restreinte'
                  : '${picked.name} ne verra plus vos stories'),
        ),
        backgroundColor: echec != null ? Colors.red : null,
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    StoryListMember member,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final echec = await ref
        .read(storyActionsNotifierProvider.notifier)
        .setListMember(member.memberId, null);
    if (echec != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(echec), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSectionLabel(
          label,
          trailing: TextButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Ajouter'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            explication,
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Personne pour le moment.',
              style: TextStyle(color: context.textTertiaryColor),
            ),
          )
        else
          DesignListCard(
            children: [
              for (final m in members)
                _MemberRow(
                  userId: m.memberId,
                  onRemove: () => _remove(context, ref, m),
                ),
            ],
          ),
      ],
    );
  }
}

class _MemberRow extends ConsumerWidget {
  final String userId;
  final VoidCallback onRemove;

  const _MemberRow({required this.userId, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileNotifierProvider(userId)).valueOrNull;
    final name = profile?.displayName ?? 'Membre';
    return ListTile(
      leading: _Avatar(name: name, photoUrl: profile?.photoUrl),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: 'Retirer',
        icon: Icon(Icons.close_rounded, color: context.textTertiaryColor),
        onPressed: onRemove,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _Avatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: 18,
      backgroundColor: context.surfaceVariantColor,
      backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: context.textPrimaryColor),
            ),
    );
  }
}

class _Person {
  final String id;
  final String name;
  final String? photoUrl;

  const _Person({required this.id, required this.name, this.photoUrl});
}

/// Choisir une personne : mes amis d'abord, puis la recherche parmi tous les
/// membres (on peut masquer ses stories à quelqu'un qui n'est pas un ami).
class _PersonPicker extends ConsumerStatefulWidget {
  final Set<String> exclude;

  const _PersonPicker({required this.exclude});

  @override
  ConsumerState<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends ConsumerState<_PersonPicker> {
  final _search = TextEditingController();
  final _profiles = ProfileSupabaseDataSource();
  Timer? _debounce;
  List<_Person> _results = const [];
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() => _query = query);
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final found = await _profiles.searchProfiles(query);
        if (!mounted || _query != query) return;
        setState(() {
          _results = [
            for (final p in found)
              _Person(
                id: p.id,
                name: p.displayName ?? 'Membre',
                photoUrl: p.photoUrl,
              ),
          ];
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final lower = _query.toLowerCase();

    final people = <_Person>[
      if (_query.length < 2)
        for (final f in friends)
          _Person(id: f.id, name: f.displayName, photoUrl: f.photoUrl)
      else ...[
        for (final f in friends)
          if (f.displayName.toLowerCase().contains(lower))
            _Person(id: f.id, name: f.displayName, photoUrl: f.photoUrl),
        ..._results,
      ],
    ];
    final seen = <String>{};
    final visible = [
      for (final p in people)
        if (p.id != me && !widget.exclude.contains(p.id) && seen.add(p.id)) p,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: DesignSearchField(
                  controller: _search,
                  hintText: 'Rechercher un membre',
                  onChanged: _onChanged,
                ),
              ),
              if (_searching) const LinearProgressIndicator(minHeight: 2),
              if (_query.length < 2)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DesignSectionLabel('MES AMIS'),
                  ),
                ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          _query.length < 2
                              ? 'Tapez au moins deux lettres pour chercher.'
                              : 'Aucun membre trouvé.',
                          style: TextStyle(color: context.textTertiaryColor),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, i) {
                          final p = visible[i];
                          return ListTile(
                            leading: _Avatar(name: p.name, photoUrl: p.photoUrl),
                            title: Text(p.name),
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
