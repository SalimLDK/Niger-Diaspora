import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/profile_share_datasource.dart';
import '../../domain/entities/profile_share_link_entity.dart';

part 'profile_share_provider.g.dart';

const String _baseShareUrl = 'https://diasponiger.com/p/';

@riverpod
ProfileShareDataSource profileShareDataSource(Ref ref) {
  return ProfileShareDataSourceImpl();
}

@riverpod
class ProfileShareNotifier extends _$ProfileShareNotifier {
  @override
  AsyncValue<ProfileShareLinkEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<String?> generateShareLink() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;

    if (currentUser == null) {
      state = AsyncValue.error('Utilisateur non connecté', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(profileShareDataSourceProvider);
      final shareLink = await dataSource.generateShareLink(currentUser.id);
      state = AsyncValue.data(shareLink.toEntity());
      return '$_baseShareUrl${shareLink.shortCode}';
    } catch (e) {
      // Fallback: utiliser l'ID utilisateur directement si la génération échoue
      final fallbackUrl = '${_baseShareUrl}u/${currentUser.id}';
      state = AsyncValue.data(
        ProfileShareLinkEntity(
          id: 'fallback',
          userId: currentUser.id,
          shortCode: 'u/${currentUser.id}',
          createdAt: DateTime.now(),
          clickCount: 0,
        ),
      );
      return fallbackUrl;
    }
  }

  Future<void> copyLinkToClipboard() async {
    final link = await generateShareLink();
    if (link != null) {
      await Clipboard.setData(ClipboardData(text: link));
    }
  }

  Future<void> shareViaSystem({String? customMessage}) async {
    final link = await generateShareLink();
    if (link != null) {
      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      final message =
          customMessage ?? 'Découvrez mon profil sur Diaspo Niger: $link';
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Profil de ${currentUser?.displayName ?? "Utilisateur"}',
        ),
      );
    }
  }

  String getQRCodeData(String shortCode) {
    return '$_baseShareUrl$shortCode';
  }
}

@riverpod
Future<String?> profileUserIdFromShareCode(Ref ref, String shortCode) async {
  final dataSource = ref.watch(profileShareDataSourceProvider);
  return await dataSource.getUserIdByShareCode(shortCode);
}
