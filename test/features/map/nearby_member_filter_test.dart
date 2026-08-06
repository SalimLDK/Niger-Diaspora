import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/map/domain/nearby_member_filter.dart';
import 'package:diaspo_niger/features/profile/data/models/profile_model.dart';

/// Décision d'affichage d'un membre sur la carte « membres autour ».
///
/// Ces tests existent parce que la branche qui **retire** un membre du flux
/// temps réel n'a jamais pu être prouvée sur appareil : cinq tentatives, cinq
/// échecs, tous dus au téléphone (écran changé entre la requête SQL et la
/// capture, application tuée par `lmkd` en build debug) et non au code.
///
/// Le trajet websocket, lui, EST prouvé sur appareil le 2026-08-05 : un membre
/// déplacé en SQL a bougé sur la carte 5,7 s plus tard, sondage exclu par
/// l'arithmétique. Ce qui restait à vérifier, c'est le verdict — et c'est
/// exactement ce que ces tests couvrent.
void main() {
  // Repères fixes : le compte de test, à Montréal.
  const centreLat = 45.58028;
  const centreLng = -73.6459;
  final maintenant = DateTime.utc(2026, 8, 6, 12, 0);

  ProfileModel membre({
    String id = 'membre-b',
    double? latitude = 45.598,
    double? longitude = -73.6459,
    bool isVisible = true,
    bool shareLocation = true,
    bool isOnline = false,
    DateTime? lastSeen,
    DateTime? locationUpdatedAt,
    String? currentCountry = 'CA',
    List<String> blockedByUserIds = const [],
  }) {
    return ProfileModel(
      id: id,
      latitude: latitude,
      longitude: longitude,
      isVisible: isVisible,
      shareLocation: shareLocation,
      isOnline: isOnline,
      lastSeen: lastSeen,
      locationUpdatedAt: locationUpdatedAt ?? maintenant,
      currentCountry: currentCountry,
      blockedByUserIds: blockedByUserIds,
    );
  }

  bool verdict(
    ProfileModel m, {
    double rayonKm = 50,
    String? paysUtilisateur = 'CA',
    String? idUtilisateurCourant = 'moi',
    Set<String> idsBloques = const {},
    double? lat = centreLat,
    double? lng = centreLng,
  }) {
    return membreVisibleSurCarte(
      membre: m,
      centreLatitude: lat,
      centreLongitude: lng,
      rayonKm: rayonKm,
      paysUtilisateur: paysUtilisateur,
      idUtilisateurCourant: idUtilisateurCourant,
      idsBloques: idsBloques,
      maintenant: maintenant,
    );
  }

  group('la branche qui retire — le cas jamais prouve sur appareil', () {
    test('un membre a 2 km, position fraiche, est garde', () {
      expect(verdict(membre()), isTrue);
    });

    test('le meme membre deplace a 230 km sort du rayon de 50 km', () {
      // Region de Quebec : c'est exactement le deplacement SQL joue cinq fois
      // sur l'appareil sans jamais pouvoir etre observe.
      final loin = membre(latitude: 46.8139, longitude: -71.2080);
      expect(verdict(loin), isFalse);
    });

    test('juste au-dela du rayon : sorti', () {
      // 50 km => delta de 0,4505 degre de latitude.
      final auBord = membre(latitude: centreLat + 0.46, longitude: centreLng);
      expect(verdict(auBord), isFalse);
    });

    test('juste en deca du rayon : garde', () {
      final auBord = membre(latitude: centreLat + 0.44, longitude: centreLng);
      expect(verdict(auBord), isTrue);
    });

    test('couper le partage de position retire le membre', () {
      expect(verdict(membre(shareLocation: false)), isFalse);
    });

    test('devenir invisible retire le membre', () {
      expect(verdict(membre(isVisible: false)), isFalse);
    });

    test('sans coordonnees, rien a placer', () {
      expect(verdict(membre(latitude: null, longitude: null)), isFalse);
    });

    test('sans position connue de notre cote, aucun membre n est situable', () {
      expect(verdict(membre(), lat: null, lng: null), isFalse);
    });
  });

  group('presence — les deux portes du filtre', () {
    test('position vieille de 4 minutes : encore frais', () {
      final m = membre(
        locationUpdatedAt: maintenant.subtract(const Duration(minutes: 4)),
      );
      expect(verdict(m), isTrue);
    });

    test('position vieille de 6 minutes, hors ligne : perime', () {
      final m = membre(
        locationUpdatedAt: maintenant.subtract(const Duration(minutes: 6)),
      );
      expect(verdict(m), isFalse);
    });

    test('position perimee mais en ligne depuis 30 min : garde', () {
      // Seconde porte : `isOnline` avec un `lastSeen` de moins d'une heure
      // rattrape une position qui a vieilli.
      final m = membre(
        locationUpdatedAt: maintenant.subtract(const Duration(hours: 3)),
        isOnline: true,
        lastSeen: maintenant.subtract(const Duration(minutes: 30)),
      );
      expect(verdict(m), isTrue);
    });

    test('en ligne mais vu il y a 2 h, position perimee : retire', () {
      final m = membre(
        locationUpdatedAt: maintenant.subtract(const Duration(hours: 3)),
        isOnline: true,
        lastSeen: maintenant.subtract(const Duration(hours: 2)),
      );
      expect(verdict(m), isFalse);
    });

    test('marque en ligne sans lastSeen : ne suffit pas', () {
      final m = membre(
        locationUpdatedAt: maintenant.subtract(const Duration(hours: 3)),
        isOnline: true,
      );
      expect(verdict(m), isFalse);
    });
  });

  group('exclusions', () {
    test('on ne figure jamais dans ses propres membres autour', () {
      expect(verdict(membre(id: 'moi')), isFalse);
    });

    test('un membre que j ai bloque est retire', () {
      expect(verdict(membre(), idsBloques: {'membre-b'}), isFalse);
    });

    test('un membre qui m a bloque est retire', () {
      expect(verdict(membre(blockedByUserIds: const ['moi'])), isFalse);
    });
  });

  group('rayons speciaux', () {
    test('rayon -1 (monde entier) garde un membre a l autre bout', () {
      final tokyo = membre(latitude: 35.68, longitude: 139.69);
      expect(verdict(tokyo, rayonKm: -1), isTrue);
    });

    test('rayon 0 (pays entier) garde un membre lointain du meme pays', () {
      final vancouver = membre(latitude: 49.28, longitude: -123.12);
      expect(verdict(vancouver, rayonKm: 0), isTrue);
    });

    test('rayon 0 retire un membre d un autre pays', () {
      final paris = membre(
        latitude: 48.85,
        longitude: 2.35,
        currentCountry: 'FR',
      );
      expect(verdict(paris, rayonKm: 0), isFalse);
    });

    test('rayon 0 sans pays connu ne borne pas', () {
      final paris = membre(
        latitude: 48.85,
        longitude: 2.35,
        currentCountry: 'FR',
      );
      expect(verdict(paris, rayonKm: 0, paysUtilisateur: null), isTrue);
    });
  });
}
