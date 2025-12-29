import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/datasources/legal_remote_datasource.dart';
import '../../data/models/legal_content_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'legal_provider.g.dart';

@riverpod
LegalRemoteDataSource legalDataSource(Ref ref) {
  return LegalRemoteDataSourceImpl();
}

@riverpod
Future<LegalContentModel> terms(Ref ref) async {
  final dataSource = ref.watch(legalDataSourceProvider);
  return dataSource.getTerms();
}

@riverpod
Future<LegalContentModel> privacyPolicy(Ref ref) async {
  final dataSource = ref.watch(legalDataSourceProvider);
  return dataSource.getPrivacyPolicy();
}

@riverpod
Future<LegalContentModel> codeOfConduct(Ref ref) async {
  final dataSource = ref.watch(legalDataSourceProvider);
  return dataSource.getCodeOfConduct();
}

@riverpod
Future<bool> needsLegalAcceptance(Ref ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return false;

  final dataSource = ref.watch(legalDataSourceProvider);
  return dataSource.needsAcceptance(user.id);
}

@riverpod
class LegalAcceptanceNotifier extends _$LegalAcceptanceNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> acceptTerms() async {
    state = const AsyncLoading();

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.valueOrNull;
      if (user == null) {
        state = AsyncError('Utilisateur non connecté', StackTrace.current);
        return;
      }

      final dataSource = ref.read(legalDataSourceProvider);

      // Récupérer les versions actuelles
      final terms = await dataSource.getTerms();
      final privacy = await dataSource.getPrivacyPolicy();

      // Sauvegarder l'acceptation
      final acceptance = UserLegalAcceptance(
        termsVersion: terms.version,
        privacyVersion: privacy.version,
        acceptedAt: DateTime.now(),
      );

      await dataSource.saveUserAcceptance(user.id, acceptance);

      // Invalider le cache pour forcer une nouvelle vérification
      ref.invalidate(needsLegalAcceptanceProvider);

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
