import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/l10n/locale_provider.dart';
import 'core/services/notification_service.dart';

class NigerDiasporaApp extends ConsumerStatefulWidget {
  const NigerDiasporaApp({super.key});

  @override
  ConsumerState<NigerDiasporaApp> createState() => _NigerDiasporaAppState();
}

class _NigerDiasporaAppState extends ConsumerState<NigerDiasporaApp> {
  @override
  void initState() {
    super.initState();
    // Setup callback after first frame to ensure router is ready
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _setupNotificationCallback();
    });
  }

  void _setupNotificationCallback() {
    // debugPrint('Setting up notification tap callback...');
    NotificationService().setNotificationTapCallback((type, targetId, data) {
      // debugPrint('Notification callback triggered: type=$type, targetId=$targetId');
      // Use post-frame callback to ensure navigation happens after current frame
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _navigateToNotificationTarget(type, targetId, data);
      });
    });
  }

  void _navigateToNotificationTarget(
    String type,
    String targetId,
    Map<String, dynamic> data,
  ) {
    // debugPrint('Navigating for notification type: $type');

    try {
      final router = ref.read(routerProvider);
      String route;

      switch (type) {
        // Message notifications - use conversationId from data
        case 'message':
          final conversationId = data['conversationId'] as String? ?? targetId;
          route = '/messages/$conversationId';
          break;

        // Friend notifications - go to profile
        case 'friendRequest':
          final senderId = data['senderId'] as String? ?? targetId;
          route = '/profile/$senderId';
          break;
        case 'friendAccepted':
          final receiverId = data['receiverId'] as String? ?? targetId;
          route = '/profile/$receiverId';
          break;

        // Event notifications - use eventId from data
        case 'eventReminder':
        case 'eventAttendance':
        case 'localEvent':
        case 'eventUpdate':
          final eventId = data['eventId'] as String? ?? targetId;
          route = '/events/$eventId';
          break;

        // Order notifications - go to orders screen
        case 'order':
        case 'newOrder':
        case 'orderPaid':
        case 'orderShipped':
        case 'orderDelivered':
        case 'orderCancelled':
        case 'orderCompleted':
          route = '/marketplace/my-orders';
          break;

        // Group notifications
        case 'groupInvite':
        case 'groupJoinRequest':
        case 'groupRequestApproved':
        case 'groupRequestRejected':
          final groupId = data['groupId'] as String? ?? targetId;
          route = '/groups/$groupId';
          break;

        // Proximity notification - go to map
        case 'proximity':
          route = '/map';
          break;

        // Default: go to notifications list
        default:
          route = targetId.isNotEmpty
              ? '/notifications/$targetId'
              : '/notifications';
      }

      // debugPrint('Pushing route: $route');
      router.push(route);
    } catch (e, stackTrace) {
      // Silently ignore navigation errors - notification navigation is best-effort
      debugPrint('Error navigating to notification: $e\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeNotifierProvider);
    final themeColor = ref.watch(themeColorNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);

    return MaterialApp.router(
      title: 'Diaspo Niger',
      debugShowCheckedModeBanner: false,
      theme:
          themeColor == AppThemeColor.orange
              ? AppTheme.orangeTheme
              : AppTheme.lightTheme,
      darkTheme:
          themeColor == AppThemeColor.orange
              ? AppTheme.orangeDarkTheme
              : AppTheme.darkTheme,
      themeMode: _getThemeMode(themeMode),
      routerConfig: router,
      locale: locale,
      supportedLocales: LocaleNotifier.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
