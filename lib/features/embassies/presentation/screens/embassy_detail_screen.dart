import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../domain/entities/embassy_entity.dart';
import 'embassy_message_screen.dart';
import 'administrative_request_screen.dart';
import 'employee_search_screen.dart';

class EmbassyDetailScreen extends StatelessWidget {
  final EmbassyEntity embassy;

  const EmbassyDetailScreen({super.key, required this.embassy});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    await launchUrl(launchUri);
  }

  Future<void> _openWebsite(String url) async {
    final Uri launchUri = Uri.parse(url);
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      // debugPrint('Could not launch $url');
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    if (!await launchUrl(
      Uri.parse(googleMapsUrl),
      mode: LaunchMode.externalApplication,
    )) {
      // debugPrint('Could not launch map');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        body: DefaultTabController(
          length: 3,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Theme.of(context).primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Placeholder for cover image (could be map or flag)
                        Container(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1),
                          child: Center(
                            child: Icon(
                              Icons.account_balance,
                              size: 80,
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            embassy.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (embassy.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    titlePadding: const EdgeInsets.only(
                      left: 16,
                      bottom: 16,
                      right: 16,
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    const TabBar(
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor:
                          Colors.orange, // Keep original theme color
                      tabs: [
                        Tab(text: 'Infos'),
                        Tab(text: 'Activités'),
                        Tab(text: 'Actualités'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              children: [
                _buildInfoTab(context),
                _buildActivitiesTab(context),
                _buildNewsTab(context),
              ],
            ),
          ),
        ),
      ), // Close PopScope child (Scaffold)
    ); // Close PopScope
  }

  /// Horaires du jour, au mieux : on tente de faire correspondre le jour
  /// courant (français ou anglais) aux clés de [EmbassyEntity.openingHours],
  /// dont le format vient du back. `null` si aucune clé ne correspond.
  String? _todayHours() {
    if (embassy.openingHours.isEmpty) return null;
    final now = DateTime.now();
    final frDay = DateFormat('EEEE', 'fr_FR').format(now).toLowerCase();
    final enDay = DateFormat('EEEE', 'en_US').format(now).toLowerCase();
    for (final e in embassy.openingHours.entries) {
      final k = e.key.toLowerCase().trim();
      if (k == frDay || k == enDay) return e.value;
    }
    return null;
  }

  /// Bandeau d'état de l'ambassade (13b). Rouge fiable via le drapeau
  /// [isTemporarilyClosed] ; vert sinon, avec les horaires du jour si connus
  /// (pas de calcul « ouvert maintenant » : le format des horaires n'est pas
  /// garanti côté back).
  Widget _buildStatusBanner(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final closed = embassy.isTemporarilyClosed;
    final fg = closed ? const Color(0xFFC23E2D) : const Color(0xFF2D7D46);
    final todayHours = _todayHours();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            closed
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: fg,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  closed ? l10n.embassyTemporarilyClosed : l10n.embassyOpen,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontSize: 15,
                  ),
                ),
                if (closed) ...[
                  if (embassy.closureMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      embassy.closureMessage!,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (embassy.reopenDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.reopenExpected} : ${DateFormat('dd MMMM yyyy', 'fr_FR').format(embassy.reopenDate!)}',
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ] else if (todayHours != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.todayTitle} · $todayHours',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bandeau d'état (13b) : vert « Ouvert » (+ horaires du jour) / rouge
          // « Temporairement fermé » (+ date de réouverture).
          _buildStatusBanner(context, theme),

          // Basic Info with Official Badge confirmation text
          if (embassy.isVerified)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Compte Officiel Vérifié',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          Text(
            '${embassy.address}, ${embassy.city}, ${embassy.country}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // Main Action Buttons
          Row(
            children: [
              Expanded(
                child: _MainActionButton(
                  icon: Icons.message,
                  label: 'Contacter',
                  color: theme.colorScheme.primary,
                  enabled: !embassy.isTemporarilyClosed,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => EmbassyMessageScreen(embassy: embassy),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MainActionButton(
                  icon: Icons.description,
                  label: 'Demande',
                  color: Colors.orange,
                  enabled: !embassy.isTemporarilyClosed,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  AdministrativeRequestScreen(embassy: embassy),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MainActionButton(
                  icon: Icons.people,
                  label: 'Personnel',
                  color: Colors.teal,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => EmployeeSearchScreen(embassy: embassy),
                        ),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (embassy.phone != null)
                _ActionButton(
                  icon: Icons.call,
                  label: 'Appeler',
                  onTap:
                      embassy.isTemporarilyClosed
                          ? null
                          : () => _makePhoneCall(embassy.phone!),
                ),
              if (embassy.email != null)
                _ActionButton(
                  icon: Icons.email,
                  label: 'Email',
                  onTap: () => _sendEmail(embassy.email!),
                ),
              if (embassy.website != null)
                _ActionButton(
                  icon: Icons.language,
                  label: 'Site Web',
                  onTap: () => _openWebsite(embassy.website!),
                ),
              if (embassy.latitude != null && embassy.longitude != null)
                _ActionButton(
                  icon: Icons.directions,
                  label: 'Y aller',
                  onTap: () => _openMap(embassy.latitude!, embassy.longitude!),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Coming Soon Section
          if (embassy.upcomingServices.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.purple[600], size: 22),
                const SizedBox(width: 8),
                Text(
                  'Bientôt disponible',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  embassy.upcomingServices.map((service) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.new_releases,
                            size: 16,
                            color: Colors.purple[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            service,
                            style: TextStyle(
                              color: Colors.purple[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Services
          if (embassy.services.isNotEmpty) ...[
            Text(
              'Services Consulaires',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  embassy.services.map((service) {
                    return Chip(
                      label: Text(service),
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      side: BorderSide.none,
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Opening Hours
          if (embassy.openingHours.isNotEmpty) ...[
            Text(
              'Horaires d\'ouverture',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children:
                      embassy.openingHours.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(entry.value),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ],

          // Jurisdiction Info
          if (embassy.jurisdictionCountries.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Juridiction',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette ambassade dessert les ressortissants se trouvant dans: ',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  embassy.jurisdictionCountries.map((country) {
                    return Chip(
                      avatar: const Icon(Icons.public, size: 16),
                      label: Text(country),
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      side: BorderSide.none,
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivitiesTab(BuildContext context) {
    if (embassy.activities.isEmpty) {
      return _buildEmptyState('Aucune activité prévue pour le moment.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: embassy.activities.length,
      itemBuilder: (context, index) {
        final activity = embassy.activities[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activity.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    activity.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.date.day}/${activity.date.month}/${activity.date.year}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            activity.location,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(activity.description),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewsTab(BuildContext context) {
    if (embassy.news.isEmpty) {
      return _buildEmptyState('Aucune actualité disponible.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: embassy.news.length,
      itemBuilder: (context, index) {
        final newsItem = embassy.news[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              newsItem.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${newsItem.date.day}/${newsItem.date.month}/${newsItem.date.year}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(newsItem.content),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _MainActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:
              enabled
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                enabled
                    ? color.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: enabled ? color : Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: enabled ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isEnabled
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isEnabled ? Theme.of(context).primaryColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled ? null : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
