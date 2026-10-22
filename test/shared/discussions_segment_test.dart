import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/group_request_provider.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';
import 'package:diaspo_niger/shared/widgets/discussions_segment.dart';

Widget _app(GoRouter router, {int unread = 0}) => ProviderScope(
  overrides: [
    totalUnreadCountProvider.overrideWithValue(unread),
    receivedGroupInvitesProvider.overrideWith((ref) => Stream.value([])),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

GoRouter _router() => GoRouter(
  initialLocation: '/messages',
  routes: [
    GoRoute(
      path: '/messages',
      builder:
          (_, __) => const Scaffold(
            body: DiscussionsSegment(current: DiscussionsView.messages),
          ),
    ),
    GoRoute(
      path: '/groups',
      builder:
          (_, __) => const Scaffold(
            body: DiscussionsSegment(current: DiscussionsView.groups),
          ),
    ),
  ],
);

void main() {
  testWidgets('toucher Groupes mène à /groups, et Messages en revient', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groupes'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/groups');

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/messages');
  });

  testWidgets('le compteur de non lus se lit sur Messages seulement', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_router(), unread: 7));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
  });
}
