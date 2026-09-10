import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_auth_bridge.dart';

/// Le peu qu'on sait d'un groupe qu'on n'a pas le droit de lire.
///
/// Assez pour décider si on veut le rejoindre, et pour renseigner
/// `group_requests.group_name`, que `requestToJoinGroup` exige. Rien de plus :
/// ni description, ni membres, ni contenu.
class GroupLinkPreview {
  final String id;
  final String name;
  final String? avatarUrl;
  final int memberCount;
  final bool isPrivate;

  const GroupLinkPreview({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.memberCount,
    required this.isPrivate,
  });
}

/// Aperçu d'un groupe atteint par son lien, quand la RLS refuse la fiche.
///
/// `null` = le groupe n'existe pas (ou plus). C'est la seule façon de
/// distinguer « privé » de « supprimé » : `getGroupById` finit sur `.single()`
/// et rend le même PGRST116 dans les deux cas.
///
/// S'appuie sur `group_link_preview`, fonction SECURITY DEFINER de la
/// migration `20260910060000` — la RLS de `groups`, elle, n'a pas bougé.
final groupLinkPreviewProvider = FutureProvider.autoDispose
    .family<GroupLinkPreview?, String>((ref, groupId) async {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final rows =
          await Supabase.instance.client.rpc(
                'group_link_preview',
                params: {'p_group_id': groupId},
              )
              as List;
      if (rows.isEmpty) return null;
      final r = rows.first as Map<String, dynamic>;
      return GroupLinkPreview(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        avatarUrl: r['avatar_url'] as String?,
        memberCount: (r['member_count'] as int?) ?? 0,
        isPrivate: (r['is_private'] as bool?) ?? false,
      );
    });
