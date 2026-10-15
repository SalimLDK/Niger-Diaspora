import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Avatar d'une carte du panneau : la photo si elle charge, sinon l'initiale
/// sur fond dégradé.
///
/// La carte de l'écran Utilisateurs peignait la photo par `DecorationImage`
/// sans repli : quand le chargement échoue — CORS sur le web, lien mort —, la
/// pastille restait **blanche**, sans initiale ni rien (vu en ligne le
/// 2026-10-15 sur le compte de Mariam Kone). `errorBuilder` ramène l'initiale.
/// Pas de `WebHtmlElementStrategy.fallback` : il retombe sur un `<img>` HTML
/// qui n'appelle jamais `errorBuilder`, donc une photo morte restait blanche.
class AvatarAdmin extends StatefulWidget {
  const AvatarAdmin({
    super.key,
    required this.nom,
    this.photoUrl,
    this.taille = 48,
  });

  /// Nom, e-mail ou identifiant : sa première lettre sert d'initiale.
  final String? nom;
  final String? photoUrl;
  final double taille;

  /// Première lettre, en majuscule ; `U` quand il n'y a rien à lire.
  static String initiale(String? nom) {
    final texte = nom?.trim() ?? '';
    return texte.isEmpty ? 'U' : String.fromCharCode(texte.runes.first).toUpperCase();
  }

  /// Les photos de profil sont dans `profiles/` de Firebase Storage, lisibles
  /// par tout compte CONNECTÉ (`storage.rules`). 205 des 224 adresses stockées
  /// n'ont pas de `token=` : sans en-tête d'autorisation elles rendent 403, et
  /// le panneau n'a jamais pu en montrer une (vu le 2026-10-15).
  static bool demandeUneSession(String url) =>
      url.contains('firebasestorage.googleapis.com') && !url.contains('token=');

  @override
  State<AvatarAdmin> createState() => _AvatarAdminState();
}

class _AvatarAdminState extends State<AvatarAdmin> {
  Future<Map<String, String>?>? _entetes;

  @override
  void initState() {
    super.initState();
    final url = widget.photoUrl?.trim();
    if (url != null && url.isNotEmpty && AvatarAdmin.demandeUneSession(url)) {
      _entetes = _lireEntetes();
    }
  }

  /// `null` sans session (ou sans Firebase, en test) : l'initiale reste.
  static Future<Map<String, String>?> _lireEntetes() async {
    try {
      final jeton = await FirebaseAuth.instance.currentUser?.getIdToken();
      return jeton == null ? null : {'Authorization': 'Firebase $jeton'};
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(12);
    final repli = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rayon,
        gradient: const LinearGradient(
          colors: [AdminColors.actionBlue, AdminColors.actionBlueLight],
        ),
      ),
      child: Center(
        child: Text(
          AvatarAdmin.initiale(widget.nom),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: widget.taille * 0.375,
          ),
        ),
      ),
    );

    final url = widget.photoUrl?.trim();
    return SizedBox(
      width: widget.taille,
      height: widget.taille,
      child: url == null || url.isEmpty
          ? repli
          : FutureBuilder<Map<String, String>?>(
              future: _entetes,
              builder: (context, instantane) {
                // On attend le jeton avant de demander l'image : la demande
                // sans en-tête partirait en 403 et ne serait pas rejouée.
                if (_entetes != null &&
                    instantane.connectionState != ConnectionState.done) {
                  return repli;
                }
                return ClipRRect(
                  borderRadius: rayon,
                  child: Image.network(
                    url,
                    headers: instantane.data,
                    width: widget.taille,
                    height: widget.taille,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => repli,
                    loadingBuilder: (_, enfant, progression) =>
                        progression == null ? enfant : repli,
                  ),
                );
              },
            ),
    );
  }
}
