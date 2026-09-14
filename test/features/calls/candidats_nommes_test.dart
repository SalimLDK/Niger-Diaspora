import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/calls/presentation/providers/eligible_participants_provider.dart';
import 'package:diaspo_niger/features/friends/domain/entities/friend_entity.dart';
import 'package:diaspo_niger/features/friends/presentation/providers/friend_provider.dart';
import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';
import 'package:diaspo_niger/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:diaspo_niger/features/profile/data/models/profile_model.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';
import 'package:diaspo_niger/features/settings/presentation/providers/blocked_users_provider.dart';

/// Les candidats à l'invitation (et à l'ajout dans un appel) portent-ils un nom ?
///
/// Ils n'en portaient aucun. `eligibleParticipantsProvider` ne lisait **jamais**
/// de profil : pour un participant de conversation qui n'est pas un ami, il
/// prenait `conversation.name` si la conversation était individuelle, et se
/// rabattait sur la chaîne « Utilisateur » sinon.
///
/// Les deux branches donnaient le repli, toujours :
///
/// * une conversation individuelle **n'a pas de nom** — `createIndividual
///   Conversation` ne l'écrit pas, et le reste de l'app résout le correspondant
///   par son profil ;
/// * une conversation de **groupe** n'entrait pas dans la branche, alors que la
///   boucle propose chacun de ses participants.
///
/// Mesuré sur SM A515F le 2026-09-14 : la feuille « Inviter un membre » ne
/// montrait que des « Utilisateur » à avatar gris — le compte de test partage un
/// fil de 21 personnes — pendant que la recherche du même écran, qui passe par
/// `searchProfiles`, nommait tout le monde.
///
/// Ce que ce test verrouille, et que `flutter analyze` ne peut pas voir : le nom
/// vient du profil, il est lu **en une seule requête**, et son échec ne fait pas
/// disparaître la liste.
void main() {
  const moi = UserEntity(id: 'moi', email: 'moi@example.com');

  ConversationEntity conversation({
    required String id,
    required ConversationType type,
    required List<String> participants,
    String? nom,
  }) => ConversationEntity(
    id: id,
    type: type,
    name: nom,
    participantIds: participants,
    createdAt: DateTime(2026, 9, 14),
    createdBy: 'moi',
  );

  ProfileModel profil(String id, String? nom, {String? photo}) =>
      ProfileModel(id: id, displayName: nom, photoUrl: photo);

  /// Clé de famille figée : `List` se compare par identité, une liste
  /// reconstruite créerait un autre provider (cf. `inviteSuggestionsProvider`).
  final aucuneExclusion = List<String>.unmodifiable(const <String>[]);

  ProviderContainer container({
    required List<ConversationEntity> conversations,
    List<FriendEntity> amis = const [],
    required _FauxProfils profils,
  }) => ProviderContainer(
    overrides: [
      currentUserAsyncProvider.overrideWith((ref) => Stream.value(moi)),
      friendsProvider.overrideWith((ref) => Stream.value(amis)),
      conversationsProvider.overrideWith((ref) => Stream.value(conversations)),
      blockedUsersProvider.overrideWith((ref) => Stream.value(const [])),
      profileRemoteDataSourceProvider.overrideWithValue(profils),
    ],
  );

  /// Le provider lit ses trois flux en `valueOrNull`, donc sa **première**
  /// passe les voit vides et une seconde suit à chaque émission. `.future`
  /// rendrait le résultat de la première : on laisse les flux se poser avant
  /// de lire, sinon le test mesure l'état transitoire au lieu du résultat.
  Future<List<EligibleParticipant>> candidats(ProviderContainer c) async {
    await c.read(currentUserAsyncProvider.future);
    await c.read(friendsProvider.future);
    await c.read(conversationsProvider.future);
    await c.read(blockedUsersProvider.future);
    return c.read(eligibleParticipantsProvider(aucuneExclusion).future);
  }

  test('un participant de conversation de GROUPE est nommé par son profil', () async {
    final profils = _FauxProfils({
      'ali': profil('ali', 'Ali Boubacar', photo: 'https://exemple/ali.jpg'),
      'fati': profil('fati', 'Fati Issa'),
    });
    final c = container(
      conversations: [
        conversation(
          id: 'conv-groupe',
          type: ConversationType.group,
          participants: ['moi', 'ali', 'fati'],
          nom: 'Diaspora Niger — NE',
        ),
      ],
      profils: profils,
    );
    addTearDown(c.dispose);

    final liste = await candidats(c);

    expect(liste.map((p) => p.displayName), ['Ali Boubacar', 'Fati Issa']);
    expect(
      liste.firstWhere((p) => p.id == 'ali').photoUrl,
      'https://exemple/ali.jpg',
      reason: 'la photo du profil doit suivre le nom',
    );
  });

  test('une conversation individuelle sans nom ne renvoie plus au repli', () async {
    final profils = _FauxProfils({'ali': profil('ali', 'Ali Boubacar')});
    final c = container(
      conversations: [
        // `name` nul : c'est l'état réel en base, `createIndividual
        // Conversation` n'écrit pas de nom.
        conversation(
          id: 'conv-1a1',
          type: ConversationType.individual,
          participants: ['moi', 'ali'],
        ),
      ],
      profils: profils,
    );
    addTearDown(c.dispose);

    expect((await candidats(c)).single.displayName, 'Ali Boubacar');
  });

  test('tous les profils sont lus en une seule requête', () async {
    final profils = _FauxProfils({
      for (var i = 0; i < 12; i++) 'u$i': profil('u$i', 'Personne $i'),
    });
    final c = container(
      conversations: [
        conversation(
          id: 'conv-groupe',
          type: ConversationType.group,
          participants: ['moi', for (var i = 0; i < 12; i++) 'u$i'],
        ),
      ],
      profils: profils,
    );
    addTearDown(c.dispose);

    final liste = await candidats(c);

    expect(liste, hasLength(12));
    expect(
      profils.appels,
      1,
      reason: 'une requête par identifiant rouvrirait le défaut que '
          '`getProfilesByIds` existe pour éviter',
    );
    expect(profils.dernierLot, hasLength(12));
  });

  test("l'échec de la lecture des profils ne fait pas disparaître la liste", () async {
    final profils = _FauxProfils(const {}, echoue: true);
    final c = container(
      conversations: [
        conversation(
          id: 'conv-groupe',
          type: ConversationType.group,
          participants: ['moi', 'ali'],
        ),
      ],
      profils: profils,
    );
    addTearDown(c.dispose);

    // Hors ligne, une liste sans nom reste utilisable : les amis y sont nommés
    // par leur copie locale. La faire échouer remplacerait la feuille par
    // « Erreur de chargement », strictement pire que le défaut corrigé ici.
    final liste = await candidats(c);

    expect(liste.single.id, 'ali');
    expect(liste.single.displayName, isEmpty);
  });

  test('un ami garde son nom local et ne coûte aucune lecture', () async {
    final profils = _FauxProfils(const {});
    final c = container(
      conversations: [
        conversation(
          id: 'conv-1a1',
          type: ConversationType.individual,
          participants: ['moi', 'ali'],
        ),
      ],
      amis: [
        FriendEntity(
          id: 'ali',
          displayName: 'Ali Boubacar',
          addedAt: DateTime(2026, 9, 1),
        ),
      ],
      profils: profils,
    );
    addTearDown(c.dispose);

    final liste = await candidats(c);

    expect(liste.single.displayName, 'Ali Boubacar');
    expect(liste.single.isFriend, isTrue);
    expect(
      profils.appels,
      0,
      reason: 'le nom dénormalisé de l\'ami suffit, et il marche hors ligne',
    );
  });

  test('les candidats sans nom ferment la marche', () async {
    final profils = _FauxProfils({
      'zara': profil('zara', 'Zara Amadou'),
      // `sans-nom` est absent du faux : profil privé, ou compte supprimé.
    });
    final c = container(
      conversations: [
        conversation(
          id: 'conv-groupe',
          type: ConversationType.group,
          participants: ['moi', 'sans-nom', 'zara'],
        ),
      ],
      profils: profils,
    );
    addTearDown(c.dispose);

    // Une chaîne vide remonte en tête d'un tri alphabétique. Ce sont justement
    // les lignes sur lesquelles on ne peut rien décider : elles vont au fond.
    expect(
      (await candidats(c)).map((p) => p.displayName),
      ['Zara Amadou', ''],
    );
  });
}

/// Double de [ProfileRemoteDataSource] réduit à la seule lecture en lot.
///
/// `noSuchMethod` dispense d'écrire les quinze autres membres de l'interface,
/// et fait échouer bruyamment tout appel inattendu plutôt que de le laisser
/// rendre `null`.
class _FauxProfils implements ProfileRemoteDataSource {
  _FauxProfils(this._parId, {this.echoue = false});

  final Map<String, ProfileModel> _parId;
  final bool echoue;

  int appels = 0;
  List<String> dernierLot = const [];

  @override
  Future<List<ProfileModel>> getProfilesByIds(List<String> ids) async {
    appels++;
    dernierLot = List.of(ids);
    if (echoue) throw Exception('hors ligne');
    return [
      for (final id in ids)
        if (_parId[id] case final p?) p,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} : ce test ne prévoit pas cet appel',
  );
}
