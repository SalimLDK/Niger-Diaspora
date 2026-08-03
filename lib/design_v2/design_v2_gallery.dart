import 'package:flutter/material.dart';

import '../core/theme/adaptive_colors.dart';
import 'kit/design_kit.dart';

import 'auth/presentation/screens/login_screen.dart' as v2_login;
import 'auth/presentation/screens/register_screen.dart' as v2_register;
import 'onboarding/presentation/screens/onboarding_intro_screen.dart'
    as v2_onboarding;
import 'profile/presentation/screens/profile_config_screen.dart' as v2_config;
import 'profile/presentation/screens/profile_screen.dart' as v2_profile;
import 'messages/presentation/screens/messages_screen.dart' as v2_messages;
import 'groups/presentation/screens/groups_screen.dart' as v2_groups;
import 'home/presentation/screens/home_screen.dart' as v2_home;
import 'settings/presentation/screens/settings_screen.dart' as v2_settings;
import 'notifications/presentation/screens/notifications_screen.dart'
    as v2_notifications;
import 'search/presentation/screens/search_screen.dart' as v2_search;
import 'businesses/presentation/screens/businesses_screen.dart' as v2_businesses;
import 'marketplace/presentation/screens/marketplace_screen.dart' as v2_shop;
import 'embassies/presentation/screens/embassies_screen.dart' as v2_embassies;
import 'events/presentation/screens/events_screen.dart' as v2_events;
import 'calls/presentation/screens/call_history_screen.dart' as v2_calls;
import 'support/presentation/screens/support_tickets_screen.dart' as v2_support;
import 'transfers/presentation/screens/transfer_screen.dart' as v2_transfers;
import 'map/presentation/screens/map_screen.dart' as v2_map;

/// Galerie de test des écrans redessinés (`design_v2`).
///
/// `design_v2` n'est référencé par aucune route de production : sans ce
/// point d'entrée, rien de la refonte n'est visible sur un vrai téléphone.
/// Chaque entrée pousse l'écran de la copie, pas celui de production.
///
/// Les classes portent les mêmes noms que leurs originales — c'est
/// volontaire, pour que la bascule finale soit un simple `cp`. D'où les
/// alias d'import ci-dessus.
///
/// À supprimer, avec sa route `/design-v2`, quand la refonte est basculée.
class DesignV2Gallery extends StatelessWidget {
  const DesignV2Gallery({super.key});

  static const List<(String, String, WidgetBuilder)> _ecrans = [
    (
      '14a→14e',
      'Onboarding',
      _onboarding,
    ),
    ('15a', 'Connexion', _login),
    ('15b', 'Inscription', _register),
    ('16f→16g', 'Configuration du profil', _config),
    ('8a', 'Accueil', _home),
    ('7d, 7e', 'Carte', _map),
    ('9a', 'Messagerie', _messages),
    ('9c', 'Groupes', _groups),
    ('10a', 'Mon profil', _profile),
    ('10b', 'Réglages', _settings),
    ('12c', 'Notifications', _notifications),
    ('12d', 'Recherche', _search),
    ('12b', 'Boutique', _shop),
    ('13a', 'Événements', _events),
    ('13c', 'Appels', _calls),
    ('17a', 'Ambassades', _embassies),
    ('17c', 'Annuaire Business', _businesses),
    ('22b', 'Support', _support),
    ('12a', 'Transferts', _transfers),
  ];

  static Widget _onboarding(BuildContext _) =>
      const v2_onboarding.OnboardingIntroScreen();
  static Widget _login(BuildContext _) => const v2_login.LoginScreen();
  static Widget _register(BuildContext _) => const v2_register.RegisterScreen();
  static Widget _config(BuildContext _) => const v2_config.ProfileConfigScreen();
  static Widget _home(BuildContext _) => const v2_home.HomeScreen();
  static Widget _map(BuildContext _) => const v2_map.MapScreen();
  static Widget _messages(BuildContext _) => const v2_messages.MessagesScreen();
  static Widget _groups(BuildContext _) => const v2_groups.GroupsScreen();
  static Widget _profile(BuildContext _) => const v2_profile.ProfileScreen();
  static Widget _settings(BuildContext _) => const v2_settings.SettingsScreen();
  static Widget _notifications(BuildContext _) =>
      const v2_notifications.NotificationsScreen();
  static Widget _search(BuildContext _) => const v2_search.SearchScreen();
  static Widget _shop(BuildContext _) => const v2_shop.MarketplaceScreen();
  static Widget _events(BuildContext _) => const v2_events.EventsScreen();
  static Widget _calls(BuildContext _) => const v2_calls.CallHistoryScreen();
  static Widget _embassies(BuildContext _) =>
      const v2_embassies.EmbassiesScreen();
  static Widget _businesses(BuildContext _) =>
      const v2_businesses.BusinessesScreen();
  static Widget _support(BuildContext _) =>
      const v2_support.SupportTicketsScreen();
  static Widget _transfers(BuildContext _) =>
      const v2_transfers.TransferScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const DesignTitle('Design v2', size: 24),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _ecrans.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DesignBody(
                'Chaque entrée ouvre la copie redessinée, pas l\'écran de '
                'production. Les écrans qui ont besoin d\'un compte ou d\'une '
                'conversation peuvent rester vides — c\'est le rendu qu\'on '
                'regarde ici, pas les données.',
              ),
            );
          }
          final (maquette, titre, builder) = _ecrans[i - 1];
          return DesignListCard(
            children: [
              ListTile(
                title: Text(
                  titre,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                subtitle: Text(
                  maquette,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiaryColor,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: context.textTertiaryColor,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: builder),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
