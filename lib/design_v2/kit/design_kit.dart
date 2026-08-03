import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/adaptive_colors.dart';

/// Briques du nouveau design (maquettes 13d, 14a→14e, 15a→15d, 16f, 16g).
///
/// Le vocabulaire visuel tient en peu de choses : un fond crème, un titre
/// serif gras terminé par un point terracotta, des blocs d'illustration
/// rayés en diagonale, des puces cochées, et des contrôles à coins très
/// arrondis.
///
/// Toutes les couleurs passent par `adaptive_colors.dart` : les maquettes
/// sont en clair, mais ces composants doivent rester lisibles en thème
/// sombre (c'est exactement le piège corrigé en 78b720e).

/// Rayon des champs, cartes et boutons rectangulaires.
const double kDesignRadius = 14;

/// Rayon des boutons pilule (« Suivant → »).
const double kDesignPillRadius = 30;

/// Hauteur commune des contrôles pleine largeur.
const double kDesignControlHeight = 54;

/// Titre de page : serif gras aligné à gauche, terminé par un point d'accent
/// terracotta. C'est la signature de toute la série d'écrans.
class DesignTitle extends StatelessWidget {
  final String text;
  final double size;

  const DesignTitle(this.text, {super.key, this.size = 29});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: context.textPrimaryColor,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text),
          TextSpan(
            text: '.',
            style: base.copyWith(color: context.adaptivePrimaryColor),
          ),
        ],
      ),
    );
  }
}

/// Intertitre serif d'une section interne (« Ce que vous recevrez »,
/// « Couleur d'accent »), sans point d'accent.
class DesignSectionTitle extends StatelessWidget {
  final String text;
  final double size;

  const DesignSectionTitle(this.text, {super.key, this.size = 19});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: context.textPrimaryColor,
      ),
    );
  }
}

/// Surtitre en petites capitales espacées, façon fil d'agence
/// (« NIAMEY · PARIS · MONTRÉAL · ABIDJAN »).
class DesignEyebrow extends StatelessWidget {
  final String text;

  const DesignEyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.robotoMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: context.adaptivePrimaryColor,
      ),
    );
  }
}

/// Paragraphe d'accroche sous le titre.
class DesignBody extends StatelessWidget {
  final String text;
  final double size;

  const DesignBody(this.text, {super.key, this.size = 14.5});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        height: 1.5,
        color: context.textSecondaryColor,
      ),
    );
  }
}

/// Bloc d'illustration des maquettes : rectangle arrondi sable, rayures
/// diagonales, pictogramme centré et légende en chasse fixe.
///
/// Les maquettes sont explicites sur le fait que ce sont des emplacements
/// (« illustration — carte des membres ») : le bloc reste donc un réceptacle
/// tant que les vraies illustrations n'existent pas.
class DesignIllustration extends StatelessWidget {
  final String caption;
  final IconData? icon;

  /// Affiche la pastille de marque terracotta portant l'initiale à la place
  /// du pictogramme (écran de bienvenue).
  final bool brandMark;

  final double aspectRatio;

  const DesignIllustration({
    super.key,
    required this.caption,
    this.icon,
    this.brandMark = false,
    this.aspectRatio = 1.35,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _StripePainter(
            background: context.surfaceVariantColor,
            stripe: accent.withValues(alpha: 0.10),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (brandMark)
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'D',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: context.onPrimaryColor,
                        height: 1,
                      ),
                    ),
                  )
                else
                  Icon(
                    icon ?? Icons.image_outlined,
                    size: 34,
                    color: accent.withValues(alpha: 0.85),
                  ),
                const SizedBox(height: 14),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color background;
  final Color stripe;

  const _StripePainter({required this.background, required this.stripe});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final paint =
        Paint()
          ..color = stripe
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke;

    // Rayures à 45°, balayées sur toute la diagonale.
    const step = 18.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.background != background || old.stripe != stripe;
}

/// Puce cochée des maquettes : cercle-check fin puis texte.
class DesignCheckBullet extends StatelessWidget {
  final String text;

  const DesignCheckBullet(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_outline,
              size: 17,
              color: context.adaptivePrimaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: context.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne discrète en pied de bloc (cadenas + mention chiffrement, info…).
class DesignInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool center;

  const DesignInfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.textTertiaryColor;
    return Row(
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, height: 1.35, color: color),
          ),
        ),
      ],
    );
  }
}

/// Indicateur de page de l'onboarding : points, actif allongé.
class DesignPageDots extends StatelessWidget {
  final int count;
  final int index;

  const DesignPageDots({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.only(right: 6),
          height: 7,
          width: active ? 24 : 7,
          decoration: BoxDecoration(
            color: active ? accent : accent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Progression de la configuration du profil : segments pleins, un par étape.
class DesignStepBar extends StatelessWidget {
  final int total;
  final int current;

  const DesignStepBar({super.key, required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: i <= current ? accent : accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/// Bouton pilule terracotta avec flèche (« Suivant → », « Commencer → »).
class DesignPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Pleine largeur (dernier écran de l'onboarding) ou compact (pilule à
  /// droite de la rangée de points).
  final bool expand;
  final bool showArrow;

  const DesignPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expand = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = context.onPrimaryColor;
    final child =
        isLoading
            ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
            : Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 9),
                  Icon(Icons.arrow_forward, size: 18, color: fg),
                ],
              ],
            );

    return SizedBox(
      height: kDesignControlHeight,
      width: expand ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.adaptivePrimaryColor,
          foregroundColor: fg,
          disabledBackgroundColor: context.adaptivePrimaryColor.withValues(
            alpha: 0.55,
          ),
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDesignPillRadius),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Bouton principal pleine largeur, à coins arrondis (barre de navigation de
/// la configuration du profil, écrans d'authentification).
class DesignPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const DesignPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = context.onPrimaryColor;
    return SizedBox(
      height: kDesignControlHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.adaptivePrimaryColor,
          foregroundColor: fg,
          disabledBackgroundColor: context.adaptivePrimaryColor.withValues(
            alpha: 0.55,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDesignRadius),
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
                : Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
      ),
    );
  }
}

/// Bouton secondaire contour (« Précédent »).
class DesignSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const DesignSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kDesignControlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.surfaceColor,
          foregroundColor: context.textPrimaryColor,
          side: BorderSide(color: context.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDesignRadius),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
      ),
    );
  }
}

/// Carte sable qui regroupe des lignes à bascule, séparées par un filet.
class DesignTileGroup extends StatelessWidget {
  final List<Widget> children;

  const DesignTileGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(height: 1, thickness: 1, color: context.dividerColor),
        );
      }
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(kDesignRadius),
      ),
      child: Column(children: rows),
    );
  }
}

/// Ligne « pictogramme + titre + sous-titre + interrupteur » des cartes
/// d'autorisations et de notifications.
class DesignToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const DesignToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color:
                  enabled
                      ? context.adaptivePrimaryColor
                      : context.textTertiaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color:
                        enabled
                            ? context.textPrimaryColor
                            : context.textTertiaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.onPrimaryColor,
            activeTrackColor: context.adaptivePrimaryColor,
          ),
        ],
      ),
    );
  }
}

/// Puce sélectionnable des centres d'intérêt : contour au repos, pleine et
/// inversée une fois cochée.
class DesignSelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DesignSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Le plein reprend la couleur du texte principal : quasi noir en clair,
    // quasi blanc en sombre, donc lisible dans les deux thèmes.
    final fill = context.textPrimaryColor;
    final onFill = context.backgroundColor;
    return Material(
      color: selected ? fill : Colors.transparent,
      borderRadius: BorderRadius.circular(kDesignPillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kDesignPillRadius),
        child: Container(
          padding: EdgeInsets.fromLTRB(selected ? 14 : 18, 10, 18, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kDesignPillRadius),
            border: Border.all(
              color: selected ? fill : context.borderStrongColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 15, color: onFill),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? onFill : context.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte sable de récapitulatif (fin de configuration).
class DesignSummaryCard extends StatelessWidget {
  final String title;
  final String body;

  const DesignSummaryCard({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(kDesignRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Décoration commune aux champs et aux listes déroulantes : surface pleine,
/// bordure fine, accent au focus.
InputDecoration designInputDecoration(
  BuildContext context, {
  String? hintText,
  String? helperText,
  Color? helperColor,
  Widget? prefix,
  Widget? suffix,
  bool enabled = true,
}) {
  final radius = BorderRadius.circular(kDesignRadius);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(fontSize: 15.5, color: context.textTertiaryColor),
    helperText: helperText,
    helperStyle: TextStyle(
      fontSize: 12,
      height: 1.3,
      color: helperColor ?? context.textTertiaryColor,
    ),
    helperMaxLines: 3,
    errorStyle: TextStyle(fontSize: 12.5, color: context.errorColor),
    filled: true,
    fillColor: enabled ? context.surfaceColor : context.surfaceVariantColor,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 24),
    border: border(context.borderColor),
    enabledBorder: border(context.borderColor),
    focusedBorder: border(context.adaptivePrimaryColor, 1.6),
    errorBorder: border(context.errorColor, 1.4),
    focusedErrorBorder: border(context.errorColor, 1.6),
    disabledBorder: border(context.borderColor),
  );
}

/// Libellé au-dessus d'un champ, avec mention facultative à droite
/// (« Optionnel », « Oublié ? »).
class DesignFieldLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const DesignFieldLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Liste déroulante habillée comme les champs des maquettes.
class DesignDropdown<T> extends StatelessWidget {
  final T? value;
  final String hintText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? helperText;

  const DesignDropdown({
    super.key,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        hintText,
        style: TextStyle(fontSize: 15.5, color: context.textTertiaryColor),
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: context.textTertiaryColor,
      ),
      borderRadius: BorderRadius.circular(kDesignRadius),
      dropdownColor: context.surfaceColor,
      style: TextStyle(fontSize: 15.5, color: context.textPrimaryColor),
      decoration: designInputDecoration(
        context,
        helperText: helperText,
        enabled: onChanged != null,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
