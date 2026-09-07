import 'dart:convert';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService.instance;
});

/// Levée quand le chiffrement est demandé alors que la clé n'est pas
/// disponible, ou que le chiffrement lui-même a échoué.
///
/// Elle existe pour une seule raison : rendre IMPOSSIBLE le retour du texte
/// clair depuis [EncryptionService.encryptText]. Avant, les deux chemins
/// d'échec renvoyaient `plainText` — l'appelant écrivait donc le message en
/// clair en base sans qu'aucune erreur ne remonte nulle part.
///
/// Aujourd'hui aucun de ces chemins n'est atteignable : la clé est une
/// constante du binaire, `initialize()` ne peut pas échouer. Le filet est posé
/// pour la suite, quand la clé viendra d'une Edge Function — c'est là qu'une
/// fenêtre « pas encore de clé » deviendra réelle.
///
/// Un appelant qui l'attrape ne doit JAMAIS retomber sur le texte clair :
/// abandonner l'écriture et le signaler est la seule issue correcte.
class EncryptionUnavailableException implements Exception {
  final String message;
  const EncryptionUnavailableException(this.message);

  @override
  String toString() => 'EncryptionUnavailableException: $message';
}

class EncryptionService {
  // Singleton pattern
  static final EncryptionService instance = EncryptionService._internal();
  factory EncryptionService() => instance;
  EncryptionService._internal();

  // Clé du repli AES-256-CBC. Elle fait AUTORITÉ : c'est elle qui a chiffré
  // tout ce qui est déjà en base (`encryptionLevel = 'aes'`, comptes de
  // paiement, coordonnées de localisation). La changer rend cet existant
  // illisible — voir docs/ops/secrets_production.md § 2.
  //
  // Elle est recopiée à l'identique à DEUX autres endroits, qui doivent suivre
  // toute modification faite ici :
  //   1. `decrypt_aes_fallback()` en base — supabase/migrations/
  //      20260813170000_fix_decrypt_aes_fallback_search_path.sql. C'est le
  //      chemin VIVANT : il construit l'aperçu des notifications push.
  //   2. `ENCRYPTION_KEY` dans functions/.env, lu par functions/encryption.js
  //      (`decryptText`, aperçus des triggers Firestore hérités).
  //
  // Elle n'est PAS lue depuis `.env` : `dotenv` n'est jamais interrogé pour
  // cette valeur. Un `ENCRYPTION_KEY` posé dans le .env racine n'aurait donc
  // aucun effet — c'est ce qui a laissé functions/.env dériver sans que rien
  // ne le signale (corrigé le 2026-09-06).
  //
  // Ce n'est pas un secret : constante d'un binaire distribué, donc extractible
  // de l'APK. Le vrai chiffrement est Signal (E2EE) ; ceci n'est que le repli
  // quand aucune session Signal n'est établie.
  static const String _sharedKeyString = 'DiaspoNigerSecureKey2025ForApps!';

  encrypt.Key? _key;
  encrypt.Encrypter? _encrypter;
  bool _isInitialized = false;

  /// Initialize the encryption service with the shared key
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use the same fixed key as the server (Cloud Functions)
      // This ensures messages can be decrypted by both client and server
      final keyBytes = utf8.encode(_sharedKeyString);
      _key = encrypt.Key(Uint8List.fromList(keyBytes));
      _encrypter = encrypt.Encrypter(
        encrypt.AES(_key!, mode: encrypt.AESMode.cbc),
      );
      _isInitialized = true;
      debugPrint('🔐 Encryption service initialized with shared key');
    } catch (e) {
      // Volontairement non propagé : `initialize()` est appelé au démarrage
      // (main.dart) et depuis l'isolate de réponse rapide. Y lever ferait d'une
      // panne de clé une panne de lancement. C'est [encryptText] qui refuse de
      // travailler sans clé — au point d'usage, pas au boot.
      debugPrint('❌ Error initializing encryption service: $e');
      _isInitialized = false;
    }
  }

  /// Ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Chiffre le texte et retourne "iv:base64ciphertext".
  ///
  /// Synchrone, donc exige une initialisation préalable ([initialize], faite
  /// au démarrage). Lève [EncryptionUnavailableException] plutôt que de rendre
  /// le texte clair : un appel qui échoue ne doit jamais produire une écriture
  /// en clair silencieuse. La chaîne vide reste rendue telle quelle — il n'y a
  /// rien à protéger, et les appelants s'appuient sur ce cas.
  String encryptText(String plainText) {
    if (plainText.isEmpty) return plainText;

    if (!_isInitialized || _encrypter == null) {
      throw const EncryptionUnavailableException(
        'clé indisponible : initialize() non appelé ou échoué',
      );
    }

    try {
      final iv = encrypt.IV.fromLength(16);
      final encrypted = _encrypter!.encrypt(plainText, iv: iv);

      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('❌ Error encrypting text: $e');
      throw EncryptionUnavailableException('chiffrement échoué : $e');
    }
  }

  /// Version asynchrone qui garantit l'initialisation
  Future<String> encryptTextAsync(String plainText) async {
    await _ensureInitialized();
    return encryptText(plainText);
  }

  /// Vérifie si une chaîne est du base64 valide
  bool _isValidBase64(String str) {
    if (str.isEmpty) return false;
    // Base64 ne contient que A-Za-z0-9+/= et sa longueur doit être multiple de 4 (avec padding)
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    return base64Regex.hasMatch(str) && str.length % 4 == 0;
  }

  /// Vérifie si le texte a le format d'un message chiffré valide
  bool _looksLikeEncryptedText(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return false;

    final ivPart = parts[0];
    final ciphertextPart = parts[1];

    // L'IV en base64 pour 16 bytes doit faire exactement 24 caractères (avec padding ==)
    // ou 22-24 caractères selon le padding
    if (ivPart.length < 22 || ivPart.length > 24) return false;

    // Les deux parties doivent être du base64 valide
    if (!_isValidBase64(ivPart) || !_isValidBase64(ciphertextPart)) return false;

    // Le ciphertext doit avoir une longueur minimale (au moins un bloc AES = 16 bytes = ~24 chars en base64)
    if (ciphertextPart.length < 20) return false;

    return true;
  }

  /// Déchiffre le texte à partir du format "iv:base64ciphertext"
  /// Retourne le texte original si le format est invalide ou si le déchiffrement échoue
  String decryptText(String encryptedFullText) {
    if (encryptedFullText.isEmpty) return encryptedFullText;

    if (!_isInitialized || _encrypter == null) {
      debugPrint('⚠️ EncryptionService not initialized, returning encrypted text as-is');
      return encryptedFullText;
    }

    // Ancien format AES-GCM (« gcm:<iv>:<ciphertext> ») produit par un schéma
    // client/serveur historique désormais absent du code. Ce service (AES-CBC)
    // ne peut pas le déchiffrer : on renvoie un placeholder propre plutôt que
    // d'exposer le texte chiffré brut. Le marqueur « 🔐 Message chiffré » est
    // reconnu par la fusion des messages (message_provider) qui préserve alors
    // le texte en clair connu localement pour nos propres messages.
    if (encryptedFullText.startsWith('gcm:')) {
      return '🔐 Message chiffré';
    }

    // Vérifier si le texte ressemble vraiment à du contenu chiffré
    if (!_looksLikeEncryptedText(encryptedFullText)) {
      // Pas le bon format, c'est probablement un ancien message non chiffré
      return encryptedFullText;
    }

    try {
      final parts = encryptedFullText.split(':');
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      // En cas d'erreur de déchiffrement (clé changée, données corrompues)
      // Le message a été chiffré avec une autre clé et ne peut pas être récupéré
      debugPrint('⚠️ Decryption failed (likely different key): $e');
      return '[Message illisible]';
    }
  }

  /// Version asynchrone qui garantit l'initialisation
  Future<String> decryptTextAsync(String encryptedFullText) async {
    await _ensureInitialized();
    return decryptText(encryptedFullText);
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Remet le service à l'état « jamais armé ».
  ///
  /// Réservé aux tests : le singleton survit d'un test à l'autre, donc sans ça
  /// on ne peut pas exercer le chemin « pas de clé » — celui-là même qui
  /// écrivait en clair.
  @visibleForTesting
  void resetForTests() {
    _key = null;
    _encrypter = null;
    _isInitialized = false;
  }
}
