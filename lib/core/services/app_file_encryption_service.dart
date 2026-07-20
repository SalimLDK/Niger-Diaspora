import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Encrypts app-private media files (podcast episodes, audio room recordings)
/// so they are unreadable outside this application, even on rooted devices.
///
/// A 256-bit master key is generated on first use and stored in the
/// hardware-backed keystore (Android Keystore / iOS Keychain) via
/// flutter_secure_storage.
///
/// On-disk format of encrypted files (.enc extension):
///   [ 12 bytes nonce | N bytes AES-256-GCM ciphertext | 16 bytes GCM tag ]
class AppFileEncryptionService {
  static final AppFileEncryptionService instance = AppFileEncryptionService._();
  AppFileEncryptionService._();

  static const _keyAlias = 'app_media_master_key';
  static const _nonceLength = 12;
  static const _tagLength = 16;

  final _aesGcm = AesGcm.with256bits();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  SecretKey? _cachedKey;

  /// Returns the app media master key, generating and persisting it on first call.
  Future<SecretKey> _getMasterKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final stored = await _secureStorage.read(key: _keyAlias);
    if (stored != null) {
      _cachedKey = SecretKey(base64Decode(stored));
      return _cachedKey!;
    }

    final rng = Random.secure();
    final keyBytes =
        Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
    await _secureStorage.write(key: _keyAlias, value: base64Encode(keyBytes));
    _cachedKey = SecretKey(keyBytes);
    return _cachedKey!;
  }

  /// Encrypts [src] and writes the encrypted result to [dst].
  /// The source file is not modified.
  Future<File> encryptFile(File src, File dst) async {
    final key = await _getMasterKey();
    final plainText = await src.readAsBytes();

    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _aesGcm.encrypt(
      plainText,
      secretKey: key,
      nonce: nonce,
    );

    final builder = BytesBuilder()
      ..add(nonce)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);
    await dst.writeAsBytes(builder.takeBytes());
    return dst;
  }

  /// Decrypts an encrypted file to a temporary file named [tempName].
  ///
  /// Returns the temporary [File] on success, or `null` if the source does not
  /// exist or decryption fails.  The caller is responsible for deleting the
  /// temp file when it is no longer needed.
  Future<File?> decryptToTemp(File src, String tempName) async {
    if (!await src.exists()) return null;

    try {
      final key = await _getMasterKey();
      final encData = await src.readAsBytes();

      if (encData.length <= _nonceLength + _tagLength) return null;

      final nonce = encData.sublist(0, _nonceLength);
      final remaining = encData.sublist(_nonceLength);
      final cipherText = remaining.sublist(0, remaining.length - _tagLength);
      final tag = remaining.sublist(remaining.length - _tagLength);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));
      final plainText =
          await _aesGcm.decrypt(secretBox, secretKey: key);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$tempName');
      await tempFile.writeAsBytes(plainText);
      return tempFile;
    } catch (_) {
      return null;
    }
  }

  /// Clears the in-memory key cache (useful in tests or after logout).
  void clearCache() => _cachedKey = null;

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}
