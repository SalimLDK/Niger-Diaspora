import 'package:go_router/go_router.dart';
import '../../../features/transfers/presentation/screens/transfer_screen.dart';
import '../../../features/transfers/presentation/screens/send_money_screen.dart';
import '../../../features/transfers/presentation/screens/recipient_select_screen.dart';
import '../../../features/transfers/presentation/screens/add_recipient_screen.dart';
import '../../../features/transfers/presentation/screens/transaction_detail_screen.dart';
import '../../../features/transfers/presentation/screens/transaction_history_screen.dart';
import '../../../features/transfers/presentation/screens/friend_recipient_select_screen.dart';
import '../../../features/transfers/domain/entities/recipient_entity.dart';

/// Routes des transferts d'argent
class TransfersRoutes {
  TransfersRoutes._();

  static List<RouteBase> get routes => [
    GoRoute(
      path: '/transfers',
      builder: (context, state) => const TransferScreen(),
    ),
    GoRoute(
      path: '/transfers/send',
      builder: (context, state) => const SendMoneyScreen(),
    ),
    GoRoute(
      path: '/transfers/history',
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
    GoRoute(
      path: '/transfers/recipient',
      builder: (context, state) => const RecipientSelectScreen(),
    ),
    GoRoute(
      path: '/transfers/recipient/add',
      builder: (context, state) {
        final recipient = state.extra as RecipientEntity?;
        return AddRecipientScreen(existingRecipient: recipient);
      },
    ),
    GoRoute(
      path: '/transfers/:transactionId',
      builder: (context, state) {
        final transactionId = state.pathParameters['transactionId']!;
        return TransactionDetailScreen(transactionId: transactionId);
      },
    ),
    // Alias pour compatibilité
    GoRoute(
      path: '/transfers/recipients',
      builder: (context, state) => const RecipientSelectScreen(),
    ),
    GoRoute(
      path: '/transfers/recipients/add',
      builder: (context, state) => const FriendRecipientSelectScreen(),
    ),
  ];
}
