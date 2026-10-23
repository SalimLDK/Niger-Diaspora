// Le rôle admin du panneau se lit dans le claim du jeton, et la liste des
// admins dans Postgres — plus dans Firestore (2026-10-14).
//
// Ce qui est verrouillé ici, c'est la lecture : ce qu'un claim donne, ce
// qu'une ligne Postgres donne, et surtout ce qui ne donne RIEN — un claim
// absent, une valeur inconnue, un `is_admin` sans `admin_role` (l'admin
// fantôme). Le reste (Firebase, Supabase, la callable) est hors d'un test
// unitaire ; la callable a son propre banc dans `functions/test/`.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/domain/enums/admin_enums.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/permission_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/role_management_provider.dart';

void main() {
  group('roleDepuisClaims', () {
    test('sans claims, ou sans adminRole : none', () {
      expect(roleDepuisClaims(null), AdminRole.none);
      expect(roleDepuisClaims(const {}), AdminRole.none);
      expect(roleDepuisClaims(const {'email': 'x@y'}), AdminRole.none);
    });

    test('chacun des quatre rôles, tel quel', () {
      for (final role in AdminRole.values.where((r) => r.isAdmin)) {
        expect(roleDepuisClaims({claimRoleAdmin: role.name}), role);
      }
    });

    test('valeur inconnue, mauvaise casse ou mauvais type : none', () {
      expect(roleDepuisClaims(const {claimRoleAdmin: 'god'}), AdminRole.none);
      expect(roleDepuisClaims(const {claimRoleAdmin: 'SuperAdmin'}), AdminRole.none);
      expect(roleDepuisClaims(const {claimRoleAdmin: true}), AdminRole.none);
      expect(roleDepuisClaims(const {claimRoleAdmin: 1}), AdminRole.none);
      expect(roleDepuisClaims(const {claimRoleAdmin: null}), AdminRole.none);
    });

    test("le drapeau hérité isAdmin n'est plus un rôle, même dans un claim", () {
      expect(roleDepuisClaims(const {'isAdmin': true}), AdminRole.none);
    });
  });

  group('AdminUser.fromRow', () {
    Map<String, dynamic> ligne({bool isAdmin = true, String? role = 'contentMod'}) => {
          'id': 'uid-1',
          'email': 'a@b.c',
          'display_name': 'Ali',
          'avatar_url': 'https://img/1.png',
          'is_admin': isAdmin,
          'admin_role': role,
          'created_at': '2026-10-14T10:00:00Z',
          'last_active_at': '2026-10-14T11:30:00+00:00',
        };

    test('une ligne cohérente', () {
      final u = AdminUser.fromRow(ligne());
      expect(u.id, 'uid-1');
      expect(u.email, 'a@b.c');
      expect(u.displayName, 'Ali');
      expect(u.photoUrl, 'https://img/1.png');
      expect(u.adminRole, AdminRole.contentMod);
      expect(u.createdAt!.toUtc(), DateTime.utc(2026, 10, 14, 10));
      expect(u.lastLoginAt!.toUtc(), DateTime.utc(2026, 10, 14, 11, 30));
      expect(AdminUser.estIncoherent(ligne()), isFalse);
    });

    test("l'admin fantôme (is_admin sans admin_role) n'est PAS promu superAdmin", () {
      final row = ligne(isAdmin: true, role: null);
      expect(AdminUser.fromRow(row).adminRole, AdminRole.none);
      expect(AdminUser.estIncoherent(row), isTrue);
    });

    test("l'inverse (admin_role sans is_admin) est incohérent aussi", () {
      final row = ligne(isAdmin: false, role: 'superAdmin');
      expect(AdminUser.fromRow(row).adminRole, AdminRole.superAdmin);
      expect(AdminUser.estIncoherent(row), isTrue);
    });

    test('un compte ordinaire est cohérent et sans rôle', () {
      final row = ligne(isAdmin: false, role: null);
      expect(AdminUser.fromRow(row).adminRole, AdminRole.none);
      expect(AdminUser.estIncoherent(row), isFalse);
    });

    test('dates absentes ou illisibles : null, pas de levée', () {
      final row = ligne()
        ..['created_at'] = null
        ..['last_active_at'] = 'pas une date';
      final u = AdminUser.fromRow(row);
      expect(u.createdAt, isNull);
      expect(u.lastLoginAt, isNull);
    });
  });
}
