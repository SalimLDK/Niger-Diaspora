import 'package:flutter/material.dart';
import '../../core/theme/adaptive_colors.dart';

/// Rail de navigation gauche pour tablette/desktop (largeur 86 px), même
/// items que [CustomBottomNavigation] — cf. handoff tour 4b. Remplace la
/// barre inférieure flottante quand l'écran est assez large pour éviter la
/// double navigation.
class TabletNavigationRail extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadMessagesCount;

  const TabletNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadMessagesCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      color: context.surfaceColor,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _RailItem(
              icon: Icons.home_rounded,
              label: 'Accueil',
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _RailItem(
              icon: Icons.map_rounded,
              label: 'Carte',
              isActive: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _RailItem(
              icon: Icons.groups_rounded,
              label: 'Groupes',
              isActive: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _RailItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Messages',
              isActive: currentIndex == 3,
              onTap: () => onTap(3),
              badgeCount: unreadMessagesCount,
            ),
            _RailItem(
              icon: Icons.person_rounded,
              label: 'Profil',
              isActive: currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = context.adaptivePrimaryColor;
    final inactiveColor = context.textTertiaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isActive ? activeColor : inactiveColor,
                    size: 24,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
