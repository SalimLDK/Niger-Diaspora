import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_code_securite.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS, phase 7)
/// ----------------------------------------------
/// MLS ne protège pas contre un serveur qui substituerait un KeyPackage :
/// rien, dans le protocole, ne dit à Alice que la clé servie pour l'appareil
/// de Bob est celle de Bob. La vérification hors bande est la seule réponse,
/// et elle ne vaut que si le code **change** quand la clé change.
///
/// Un code de sécurité qui ne bougerait pas serait pire que pas de code du
/// tout : il donnerait une assurance fausse, et deux personnes se croiraient
/// protégées précisément dans le cas où elles ne le sont pas.

Uint8List _cle(int graine) =>
    Uint8List.fromList(List.generate(32, (i) => (graine + i) % 256));

void main() {
  group('Le code change quand la clé change', () {
    test('même appareil, même clé : même code', () {
      final a = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(1));
      final b = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(1));
      expect(MlsCodeSecurite.formater(a), MlsCodeSecurite.formater(b));
    });

    test('clé substituée : code différent', () {
      // LE test. Si celui-ci passait avec deux codes égaux, toute la phase 7
      // serait décorative.
      final vrai = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(1));
      final substitue = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(2));
      expect(MlsCodeSecurite.formater(vrai),
          isNot(MlsCodeSecurite.formater(substitue)));
    });

    test('même clé, identité différente : code différent', () {
      // Sinon, réutiliser la clé d'un appareil sous une autre identité
      // passerait inaperçu.
      final a = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(1));
      final b = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u2:abc', signatureKey: _cle(1));
      expect(a, isNot(b));
    });

    test('sans clé publiée, aucun code ne doit être affiché', () {
      // Deux appareils sans clé donnent le MÊME condensé : les comparer
      // conclurait « vérifié » sur du vide. D'où la garde.
      expect(MlsCodeSecurite.estCalculable(Uint8List(0)), isFalse);
      expect(MlsCodeSecurite.estCalculable(_cle(1)), isTrue);

      final a = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: Uint8List(0));
      final b = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: Uint8List(0));
      expect(a, b, reason: 'c\'est bien pour ça que la garde existe');
    });
  });

  group('La forme est comparable à voix haute', () {
    test('12 groupes de 5 chiffres', () {
      final code = MlsCodeSecurite.formater(
        MlsCodeSecurite.empreinteAppareil(
            mlsIdentity: 'u1:abc', signatureKey: _cle(1)),
      );
      final groupes = code.split(' ');
      expect(groupes, hasLength(12));
      for (final g in groupes) {
        expect(g, hasLength(5));
        expect(int.tryParse(g), isNotNull, reason: 'des chiffres, pas du texte');
      }
    });
  });

  group('Le code d\'une conversation ne dépend pas de l\'ordre', () {
    test('deux participants, lus dans les deux sens : même code', () {
      // Chacun voit la liste des membres dans son ordre à lui. Un code
      // dépendant de l'ordre ne serait jamais égal, et tout le monde
      // croirait à une substitution permanente.
      final a = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(1));
      final b = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u2:def', signatureKey: _cle(9));

      expect(MlsCodeSecurite.empreinteConversation([a, b]),
          MlsCodeSecurite.empreinteConversation([b, a]));
    });

    test('un membre de plus : code différent', () {
      final a = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(1));
      final b = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u2:def', signatureKey: _cle(9));
      final c = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u3:ghi', signatureKey: _cle(40));

      expect(MlsCodeSecurite.empreinteConversation([a, b]),
          isNot(MlsCodeSecurite.empreinteConversation([a, b, c])));
    });
  });

  group('Le QR', () {
    test('aller-retour', () {
      final empreinte = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u1:abc', signatureKey: _cle(1));
      final charge = MlsCodeSecurite.chargeQr(
          mlsIdentity: 'u1:abc', empreinte: empreinte);

      final lu = MlsCodeSecurite.lireQr(charge);
      expect(lu, isNotNull);
      expect(lu!.mlsIdentity, 'u1:abc');
      expect(lu.empreinte, empreinte);
    });

    test('un QR étranger est refusé, pas interprété', () {
      // L'écran doit dire « ce n'est pas un code de vérification ». Répondre
      // « ne correspond pas » sur un QR de profil serait une accusation
      // fausse, et la personne chercherait un attaquant qui n'existe pas.
      for (final brut in const [
        'https://diaspo-niger.app/u/salim',
        'dn-e2ee-transfer:1:u1:abcdef',
        'dn-mls-verif:2:u1:abcdef',
        'dn-mls-verif:1::abcdef',
        'texte quelconque',
        '',
      ]) {
        expect(MlsCodeSecurite.lireQr(brut), isNull, reason: brut);
      }
    });

    test('une empreinte tronquée est refusée', () {
      expect(MlsCodeSecurite.lireQr('dn-mls-verif:1:u1:AAAA'), isNull);
    });
  });

  group('Le scan compare ce qui est lu à ce que le serveur sert', () {
    /// Le QR tel que l'appareil d'en face l'affiche.
    String qrDe(String identite, Uint8List cle) => MlsCodeSecurite.chargeQr(
          mlsIdentity: identite,
          empreinte: MlsCodeSecurite.empreinteAppareil(
              mlsIdentity: identite, signatureKey: cle),
        );

    test('les deux côtés voient la même clé', () async {
      expect(
        await MlsVerificationScan.comparer(
          charge: qrDe('u2:def', _cle(1)),
          cleDe: (_) async => _cle(1),
        ),
        ResultatScan.correspond,
      );
    });

    test('le serveur sert une AUTRE clé : ne correspond pas', () async {
      // Le scénario que toute la phase 7 existe pour attraper. L'écran d'en
      // face montre sa vraie clé ; le serveur, lui, m'en a servi une autre.
      expect(
        await MlsVerificationScan.comparer(
          charge: qrDe('u2:def', _cle(1)),
          cleDe: (_) async => _cle(2),
        ),
        ResultatScan.neCorrespondPas,
      );
    });

    test('appareil absent du registre : inconnu, pas « ne correspond pas »',
        () async {
      expect(
        await MlsVerificationScan.comparer(
          charge: qrDe('u2:def', _cle(1)),
          cleDe: (_) async => null,
        ),
        ResultatScan.appareilInconnu,
      );
    });

    test('appareil sans clé publiée : inconnu', () async {
      expect(
        await MlsVerificationScan.comparer(
          charge: qrDe('u2:def', _cle(1)),
          cleDe: (_) async => Uint8List(0),
        ),
        ResultatScan.appareilInconnu,
      );
    });

    test('un QR étranger n\'est pas une non-correspondance', () async {
      // Répondre « ne correspond pas » sur un QR de profil enverrait la
      // personne chercher un attaquant qui n'existe pas.
      expect(
        await MlsVerificationScan.comparer(
          charge: 'https://diasponiger.com/p/u/salim',
          cleDe: (_) async => _cle(1),
        ),
        ResultatScan.pasUnCode,
      );
    });

    test('c\'est bien l\'identité lue qui est cherchée', () async {
      // Chercher la mauvaise ligne donnerait « ne correspond pas » sur deux
      // appareils parfaitement sains.
      String? demandee;
      await MlsVerificationScan.comparer(
        charge: qrDe('u2:def', _cle(1)),
        cleDe: (id) async {
          demandee = id;
          return _cle(1);
        },
      );
      expect(demandee, 'u2:def');
    });
  });

  group('La mémoire des vérifications', () {
    /// Mémoire en RAM : le comportement se teste sans plateforme.
    ({MlsVerifications verifs, Map<String, String> memoire}) monter() {
      final memoire = <String, String>{};
      return (
        verifs: MlsVerifications(
          userId: 'u1',
          lire: (c) async => memoire[c],
          ecrire: (c, v) async => memoire[c] = v,
          effacer: (c) async => memoire.remove(c),
        ),
        memoire: memoire,
      );
    }

    test('jamais vérifié n\'est pas une alerte', () async {
      final m = monter();
      expect(await m.verifs.etat('u2:def', _cle(1)), EtatVerification.jamais);
    });

    test('vérifié puis inchangé', () async {
      final m = monter();
      final e = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u2:def', signatureKey: _cle(1));
      await m.verifs.marquerVerifie('u2:def', e);
      expect(await m.verifs.etat('u2:def', e), EtatVerification.verifie);
    });

    test('vérifié puis la clé change : ALERTE', () async {
      // Le seul état qui mérite d'interrompre quelqu'un. Réinstallation le
      // plus souvent, substitution sinon — dans les deux cas il faut
      // revérifier avant de parler.
      final m = monter();
      await m.verifs.marquerVerifie(
        'u2:def',
        MlsCodeSecurite.empreinteAppareil(
            mlsIdentity: 'u2:def', signatureKey: _cle(1)),
      );

      final apres = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u2:def', signatureKey: _cle(2));
      expect(await m.verifs.etat('u2:def', apres), EtatVerification.changee);
    });

    test('la mémoire porte le compte : deux comptes ne se mélangent pas',
        () async {
      final memoire = <String, String>{};
      MlsVerifications pour(String uid) => MlsVerifications(
            userId: uid,
            lire: (c) async => memoire[c],
            ecrire: (c, v) async => memoire[c] = v,
            effacer: (c) async => memoire.remove(c),
          );
      final e = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u3:ghi', signatureKey: _cle(1));

      await pour('u1').marquerVerifie('u3:ghi', e);

      expect(await pour('u1').etat('u3:ghi', e), EtatVerification.verifie);
      expect(await pour('u2').etat('u3:ghi', e), EtatVerification.jamais,
          reason: 'la vérification de quelqu\'un d\'autre n\'est pas la mienne');
    });

    test('une mémoire illisible se lit « je ne sais pas », pas « alerte »',
        () async {
      final verifs = MlsVerifications(
        userId: 'u1',
        lire: (_) async => throw StateError('stockage indisponible'),
        ecrire: (_, __) async {},
        effacer: (_) async {},
      );
      expect(await verifs.etat('u2:def', _cle(1)), EtatVerification.jamais);
    });

    test('oublier ramène à « jamais »', () async {
      final m = monter();
      final e = MlsCodeSecurite.empreinteAppareil(
          mlsIdentity: 'u2:def', signatureKey: _cle(1));
      await m.verifs.marquerVerifie('u2:def', e);
      await m.verifs.oublier('u2:def');
      expect(await m.verifs.etat('u2:def', e), EtatVerification.jamais);
    });
  });
}
