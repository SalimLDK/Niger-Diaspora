import 'dart:io';

import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/e2ee/media_encryption_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/media_dechiffre_provider.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transférer un média.
///
/// Le transfert recopiait `fileUrl` dans une ligne legacy écrite directement
/// par la source de données. Un média chiffré partait donc sans sa clé —
/// blob illisible chez le destinataire —, et vers une conversation basculée
/// en MLS, le serveur refusait l'écriture. Désormais le média repart du
/// fichier en clair, par le chemin d'envoi normal : chiffré et routé selon
/// la conversation CIBLE.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final refProvider = Provider<Ref>((ref) => ref);

  late Directory racine;
  late Directory temporaire;

  setUp(() {
    HttpOverrides.global = null; // le binding répond 400 à tout HTTP
    racine = Directory.systemTemp.createTempSync('transfert_test');
    temporaire = Directory('${racine.path}/tmp')..createSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temporaire.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (racine.existsSync()) racine.deleteSync(recursive: true);
  });

  MessageEntity message({
    String? fileName,
    String? fileUrl,
    String? localFilePath,
    MediaChiffre? mediaChiffre,
  }) =>
      MessageEntity(
        id: 'm1',
        senderId: 'u2',
        senderName: 'Amina',
        content: '',
        type: MessageType.file,
        createdAt: DateTime.utc(2026, 10, 3),
        readBy: const [],
        readAt: const {},
        fileName: fileName,
        fileUrl: fileUrl,
        localFilePath: localFilePath,
        mediaChiffre: mediaChiffre,
      );

  File fichier(String nom, String contenu) =>
      File('${racine.path}/$nom')..writeAsStringSync(contenu);

  test('média chiffré : la copie vient du clair déchiffré, sous son vrai nom',
      () async {
    // Le cache de déchiffrement nomme ses fichiers d'après le message.
    final dechiffre = fichier('m1.pdf', 'contenu en clair');
    const media = MediaChiffre(
      storagePath: 'encrypted_media/c1/x',
      encryptedUrl: 'https://stockage.test/blob-chiffre',
      fileKeyBase64: 'a2V5',
      ivBase64: 'aXY=',
      fileName: 'Contrat.pdf',
      mimeType: 'application/pdf',
      size: 16,
    );
    final conteneur = ProviderContainer(overrides: [
      mediaDechiffreProvider.overrideWith((ref, d) async => dechiffre.path),
    ]);
    addTearDown(conteneur.dispose);

    final copie = await fichierEnClairPourTransfert(
      conteneur.read(refProvider),
      message(
        fileName: 'Contrat.pdf',
        fileUrl: media.encryptedUrl,
        mediaChiffre: media,
      ),
    );

    expect(copie, isNotNull);
    expect(copie!.readAsStringSync(), 'contenu en clair',
        reason: 'jamais le blob chiffré');
    expect(copie.uri.pathSegments.last, 'Contrat.pdf');
    expect(copie.path, startsWith(temporaire.path));
    expect(dechiffre.existsSync(), isTrue, reason: 'le cache reste intact');
  });

  test('fichier local d\'un envoi : copié, nom nettoyé', () async {
    final local = fichier('enregistrement.m4a', 'audio');
    final conteneur = ProviderContainer();
    addTearDown(conteneur.dispose);

    final copie = await fichierEnClairPourTransfert(
      conteneur.read(refProvider),
      message(fileName: '../../evil.m4a', localFilePath: local.path),
    );

    expect(copie!.readAsStringSync(), 'audio');
    expect(copie.uri.pathSegments.last, 'evil.m4a');
    expect(copie.parent.parent.path, '${temporaire.path}/transferts');
  });

  test('file:// : copié', () async {
    final local = fichier('photo.jpg', 'image');
    final conteneur = ProviderContainer();
    addTearDown(conteneur.dispose);

    final copie = await fichierEnClairPourTransfert(
      conteneur.read(refProvider),
      message(fileName: 'photo.jpg', fileUrl: 'file://${local.path}'),
    );

    expect(copie!.readAsStringSync(), 'image');
  });

  test('média en clair distant : téléchargé', () async {
    final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => serveur.close(force: true));
    serveur.listen((r) async {
      r.response.add('distant'.codeUnits);
      await r.response.close();
    });
    final conteneur = ProviderContainer();
    addTearDown(conteneur.dispose);

    final copie = await fichierEnClairPourTransfert(
      conteneur.read(refProvider),
      message(
        fileName: 'doc.pdf',
        fileUrl: 'http://127.0.0.1:${serveur.port}/doc',
      ),
    );

    expect(copie!.readAsStringSync(), 'distant');
    expect(copie.uri.pathSegments.last, 'doc.pdf');
  });

  test('plus rien à copier : null, pas d\'exception', () async {
    final conteneur = ProviderContainer();
    addTearDown(conteneur.dispose);
    final ref = conteneur.read(refProvider);

    expect(await fichierEnClairPourTransfert(ref, message()), isNull);
    expect(
      await fichierEnClairPourTransfert(
        ref,
        message(localFilePath: '${racine.path}/disparu.m4a'),
      ),
      isNull,
    );
  });

  test('un média chiffré transféré garde sa mention « Transféré »', () async {
    // Le chemin chiffré de sendFileMessage ignorait la mention : le
    // transfert, désormais routé par lui, l'aurait perdue.
    final source = _SourceEspion();
    final depot = MessageRepositoryImpl(
      remoteDataSource: source,
      networkInfo: _Reseau(),
      mediaEncryptionService: _ChiffrementFige(),
      mediasChiffresActifs: () => true,
    );

    final r = await depot.sendFileMessage(
      conversationId: 'c1',
      senderId: 'u1',
      senderName: 'Moi',
      file: fichier('Contrat.pdf', 'clair'),
      type: MessageType.file,
      isForwarded: true,
    );

    expect(r.isRight(), isTrue, reason: '$r');
    expect(source.transfere, isTrue);
    expect(source.mediaChiffre, isNotNull, reason: 'la clé voyage');
  });

  test('le transfert ne réécrit plus directement par la source de données',
      () {
    final source = File(
      'lib/features/messages/presentation/providers/message_provider.dart',
    ).readAsStringSync();
    final debut = source.indexOf('Future<bool> forwardMessage(');
    final fin = source.indexOf('case MessageType.location:', debut);
    final medias = source.substring(debut, fin);
    expect(medias, isNot(contains('messageRemoteDataSourceProvider')));
    expect(medias, contains('fichierEnClairPourTransfert('));
    expect(medias, contains('isForwarded: true'));
  });
}

class _Reseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChiffrementFige extends MediaEncryptionService {
  @override
  Future<EncryptedMediaResult> encryptAndUploadFile({
    required File file,
    required String conversationId,
    required String senderId,
    required MediaType mediaType,
    void Function(double progress)? onProgress,
    bool Function()? checkCancelled,
  }) async =>
      EncryptedMediaResult(
        encryptedUrl: 'https://stockage.test/blob',
        storagePath: 'encrypted_media/c1/blob',
        fileKeyBase64: 'a2V5',
        ivBase64: 'aXY=',
        originalFileName: 'Contrat.pdf',
        originalSize: 5,
        encryptedSize: 33,
        mediaType: mediaType,
        mimeType: 'application/pdf',
      );
}

class _SourceEspion implements MessageRemoteDataSource {
  bool? transfere;
  Map<String, dynamic>? mediaChiffre;

  @override
  Future<MessageModel> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    required String mimeType,
    required String type,
    String? caption,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
    String? thumbnailUrl,
    int? videoDuration,
    int? audioDuration,
    List<double>? audioWaveform,
    String? blurhash,
    Map<String, dynamic>? mediaChiffre,
  }) async {
    transfere = isForwarded;
    this.mediaChiffre = mediaChiffre;
    return MessageModel(
      id: 'nouveau',
      senderId: senderId,
      senderName: senderName,
      content: '',
      createdAt: DateTime.utc(2026, 10, 3),
      type: type,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
