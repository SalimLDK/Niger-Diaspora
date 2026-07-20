import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icone SVG custom (assets/icons/), teintee dynamiquement via colorFilter
/// pour s'adapter au theme et au code couleur par type de contenu.
class AppIcon extends StatelessWidget {
  static const pin = 'icon_pin.svg';
  static const event = 'icon_event.svg';
  static const poll = 'icon_poll.svg';
  static const pinnedMessage = 'icon_pinned_message.svg';

  // Set moderne (phase 1) - remplace les Icons.* Material les plus utilises.
  static const error = 'icon_error.svg';
  static const close = 'icon_close.svg';
  static const person = 'icon_person.svg';
  static const checkCircle = 'icon_check_circle.svg';
  static const arrowBack = 'icon_arrow_back.svg';
  static const video = 'icon_video.svg';
  static const delete = 'icon_delete.svg';
  static const search = 'icon_search.svg';
  static const groups = 'icon_groups.svg';
  static const check = 'icon_check.svg';
  static const add = 'icon_add.svg';
  static const star = 'icon_star.svg';
  static const location = 'icon_location.svg';
  static const send = 'icon_send.svg';
  static const info = 'icon_info.svg';
  static const doneAll = 'icon_done_all.svg';
  static const chevronRight = 'icon_chevron_right.svg';
  static const call = 'icon_call.svg';
  static const podcasts = 'icon_podcasts.svg';
  static const people = 'icon_people.svg';
  static const clock = 'icon_clock.svg';
  static const lock = 'icon_lock.svg';
  static const personAdd = 'icon_person_add.svg';
  static const heart = 'icon_heart.svg';
  static const share = 'icon_share.svg';
  static const refresh = 'icon_refresh.svg';
  static const flag = 'icon_flag.svg';
  static const bank = 'icon_bank.svg';
  static const mic = 'icon_mic.svg';
  static const image = 'icon_image.svg';
  static const chatBubble = 'icon_chat_bubble.svg';
  static const cancel = 'icon_cancel.svg';
  static const warning = 'icon_warning.svg';

  // Logos de marque (partage social) - glyphes officiels Simple Icons (CC0).
  static const whatsapp = 'icon_whatsapp.svg';
  static const facebook = 'icon_facebook.svg';
  static const x = 'icon_x.svg';

  // Set moderne (phase 2) - contreparties pour les toggles/etats.
  static const starBorder = 'icon_star_border.svg';
  static const favoriteBorder = 'icon_favorite_border.svg';
  static const lockOpen = 'icon_lock_open.svg';
  static const micOff = 'icon_mic_off.svg';
  static const videocamOff = 'icon_videocam_off.svg';
  static const circleOutline = 'icon_circle_outline.svg';
  static const public = 'icon_public.svg';
  static const store = 'icon_store.svg';
  static const searchOff = 'icon_search_off.svg';
  static const archive = 'icon_archive.svg';

  final String asset;
  final double size;
  // Nullable comme Icon.color : retombe sur IconTheme puis noir si non fourni.
  final Color? color;

  const AppIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return SvgPicture.asset(
      'assets/icons/$asset',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}
