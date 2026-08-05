import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../domain/entities/notification_entity.dart';

/// Langage visuel commun aux ecrans de notifications (liste et detail).
///
/// Il vit a part parce que les deux ecrans doivent peindre la meme
/// famille de la meme facon : c'est en le laissant dupliquer que l'un
/// s'est retrouve en vert WhatsApp et l'autre en `Colors.indigo`.

/// Teinte d'une famille de notifications (§12c).
///
/// La maquette tient sur **quatre teintes** prises au thème, là où l'écran en
/// alignait une vingtaine en dur (`Colors.purple`, `Colors.indigo`,
/// `Colors.amber`…) plus un `0xFF25D366` vert WhatsApp qui n'appartient à
/// aucune palette du projet. Le thème sombre n'était pas prévu non plus : ces
/// couleurs sont des constantes Material, elles ne s'adaptent pas.
Color notificationTint(BuildContext context, NotificationType type) {
  switch (type) {
    // Messages et contenu courant : l'accent de l'app.
    case NotificationType.message:
    case NotificationType.general:
      return context.adaptivePrimaryColor;

    // Ce qui rassemble : groupes et événements.
    case NotificationType.groupInvite:
    case NotificationType.groupJoinRequest:
    case NotificationType.groupRequestApproved:
    case NotificationType.newMember:
    case NotificationType.eventReminder:
    case NotificationType.eventUpdate:
    case NotificationType.eventAttendance:
    case NotificationType.localEvent:
      return context.successColor;

    // Les gens : demandes, abonnements, présence à proximité.
    case NotificationType.friendRequest:
    case NotificationType.friendRequestAccepted:
    case NotificationType.friendAccepted:
    case NotificationType.newFollower:
    case NotificationType.nearbyMember:
    case NotificationType.proximityAlert:
      return context.adaptiveSecondaryColor;

    // Les transactions.
    case NotificationType.order:
    case NotificationType.newOrder:
    case NotificationType.orderPaid:
    case NotificationType.orderShipped:
    case NotificationType.orderDelivered:
    case NotificationType.orderCompleted:
      return context.goldColor;

    // Ce qui a échoué.
    case NotificationType.groupRequestRejected:
    case NotificationType.orderCancelled:
      return context.errorColor;
  }
}

/// Pictogramme d'une famille de notifications.
IconData notificationIcon(NotificationType type) {
  switch (type) {
    case NotificationType.message:
      return Icons.chat_bubble_outline;
    case NotificationType.groupInvite:
    case NotificationType.groupJoinRequest:
      return Icons.group_add_outlined;
    case NotificationType.newMember:
      return Icons.groups_outlined;
    case NotificationType.groupRequestApproved:
      return Icons.check_circle_outline;
    case NotificationType.groupRequestRejected:
      return Icons.cancel_outlined;
    case NotificationType.eventReminder:
    case NotificationType.localEvent:
      return Icons.event_outlined;
    case NotificationType.eventUpdate:
      return Icons.edit_calendar_outlined;
    case NotificationType.eventAttendance:
      return Icons.event_available_outlined;
    case NotificationType.friendRequest:
    case NotificationType.newFollower:
      return Icons.person_add_alt;
    case NotificationType.friendRequestAccepted:
    case NotificationType.friendAccepted:
      return Icons.how_to_reg_outlined;
    case NotificationType.nearbyMember:
      return Icons.person_pin_circle_outlined;
    case NotificationType.proximityAlert:
      return Icons.location_on_outlined;
    case NotificationType.order:
    case NotificationType.newOrder:
      return Icons.shopping_bag_outlined;
    case NotificationType.orderPaid:
      return Icons.payments_outlined;
    case NotificationType.orderShipped:
      return Icons.local_shipping_outlined;
    case NotificationType.orderDelivered:
    case NotificationType.orderCompleted:
      return Icons.check_circle_outline;
    case NotificationType.orderCancelled:
      return Icons.cancel_outlined;
    case NotificationType.general:
      return Icons.notifications_none;
  }
}

/// Horodatage en chasse fixe capitale de la maquette (« IL Y A 12 MIN »,
/// « HIER », « LUNDI »).
String notificationStamp(BuildContext context, DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'À L\'INSTANT';
  if (diff.inMinutes < 60) return 'IL Y A ${diff.inMinutes} MIN';
  if (diff.inHours < 24) return 'IL Y A ${diff.inHours} H';

  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (today.difference(day).inDays == 1) return 'HIER';
  if (today.difference(day).inDays < 7) {
    return DateFormat(
      'EEEE',
      LocaleHelper.getDateFormatLocale(context),
    ).format(date).toUpperCase();
  }
  return DateFormat(
    'd MMM',
    LocaleHelper.getDateFormatLocale(context),
  ).format(date).toUpperCase();
}
