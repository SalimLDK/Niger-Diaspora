/// Divulgation préalable de l'usage de la position (« Prominent Disclosure »).
///
/// Google Play a refusé l'envoi du 2026-09-09 pour « Inadequate Prominent
/// Disclosure : the in-app Prominent Disclosure does not disclose the usage of
/// accessed or collected Location data ». La capture jointe au refus était
/// l'écran 5/5 de l'onboarding, dont la seule mention de position disait
/// « Réciproque : vous voyez ceux qui partagent » — ce qui décrit un bénéfice,
/// pas une collecte.
///
/// Ce que la règle exige, et que ce fichier est seul à porter :
///
/// - le texte nomme l'application, la **donnée collectée**, l'**usage** et le
///   **partage** (« visible par les autres membres ») ;
/// - il s'affiche **dans l'application**, sans que la personne ait à ouvrir un
///   menu, et **avant** la boîte système d'autorisation ;
/// - il n'est pas noyé dans un texte sans rapport (CGU, politique) ;
/// - il se conclut par une **action affirmative** — un bouton d'acceptation —
///   avec un refus possible.
///
/// Le texte suit l'usage, parce que la règle porte sur l'usage : dire « visible
/// par les autres membres » quand la position part dans une seule discussion
/// serait faux, et une divulgation fausse ne vaut pas mieux qu'aucune. D'où
/// [UsageLocalisation], et la formule attendue mot pour mot pour une collecte
/// hors premier plan — « même lorsque l'application est fermée ou n'est pas
/// utilisée » — réservée au Mode Voyage, seul à publier une position toutes
/// les 5 minutes tant que son service tourne.
library;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../theme/adaptive_colors.dart';
import '../theme/design_kit.dart';

/// Ce à quoi la position va servir, et donc le texte à afficher.
enum UsageLocalisation {
  /// Carte des membres et voisinage : la position devient visible par les
  /// autres membres. Accueil, Carte, onboarding.
  carte,

  /// Mode Voyage : publication toutes les 5 minutes hors premier plan.
  arrierePlan,

  /// Position insérée dans un message : partagée avec les seuls participants
  /// de la discussion, et seulement à l'envoi.
  discussion,
}

/// Bloc de divulgation posé **dans** un écran (onboarding 5/5).
///
/// Sert quand l'écran porte déjà l'action affirmative — le bouton
/// « Commencer », qui déclenche les demandes système. Le texte doit donc être
/// visible sans défilement supplémentaire, juste au-dessus de ce bouton.
class LocationDisclosureNotice extends StatelessWidget {
  const LocationDisclosureNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = context.adaptivePrimaryColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(kDesignRadius),
        border: Border.all(color: context.outlineColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline, size: 14, color: accent),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  l10n.locationDisclosureTitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            l10n.locationDisclosureShort,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 2),
          _LienPolitique(
            label: l10n.locationDisclosureReadPolicy,
            fontSize: 11.5,
          ),
        ],
      ),
    );
  }
}

/// Affiche la divulgation en feuille modale et attend une réponse explicite.
///
/// Renvoie `true` seulement sur appui du bouton d'acceptation : un balayage
/// vers le bas, un retour arrière ou le bouton de refus valent refus, et
/// l'appelant ne doit alors **rien** demander au système.
///
/// [usage] choisit le texte : voir [UsageLocalisation].
Future<bool> afficherDivulgationLocalisation(
  BuildContext context, {
  UsageLocalisation usage = UsageLocalisation.carte,
}) async {
  final accepte = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FeuilleDivulgation(usage: usage),
  );
  return accepte ?? false;
}

/// Porte d'entrée unique de la localisation au premier plan.
///
/// À appeler **avant** toute lecture de position depuis un écran. Elle ne
/// montre la divulgation que lorsque le système s'apprête réellement à poser
/// la question : autorisation déjà accordée, rien à divulguer (le
/// consentement a été donné une fois pour toutes) ; refus définitif, la boîte
/// système ne s'ouvrira plus, inutile d'expliquer.
///
/// Sans cette porte, une personne qui passe l'onboarding (« Passer », « Plus
/// tard, sans autorisations ») tombait sur la boîte système à l'ouverture de
/// l'accueil ou de la carte, sans avoir jamais lu à quoi sert sa position —
/// exactement le manquement relevé par Google. C'est aussi le parcours d'un
/// examinateur pressé.
///
/// Renvoie `true` si la position peut être lue.
Future<bool> demanderLocalisationAvecDivulgation(
  BuildContext context, {
  UsageLocalisation usage = UsageLocalisation.carte,
}) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse) {
    return true;
  }
  if (permission == LocationPermission.deniedForever) return false;

  if (!context.mounted) return false;
  final accepte = await afficherDivulgationLocalisation(context, usage: usage);
  if (!accepte) return false;

  permission = await Geolocator.requestPermission();
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}

class _FeuilleDivulgation extends StatelessWidget {
  final UsageLocalisation usage;

  const _FeuilleDivulgation({required this.usage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titre = switch (usage) {
      UsageLocalisation.carte => l10n.locationDisclosureTitle,
      UsageLocalisation.arrierePlan => l10n.locationDisclosureBackgroundTitle,
      UsageLocalisation.discussion => l10n.locationDisclosureChatTitle,
    };
    final corps = switch (usage) {
      UsageLocalisation.carte => l10n.locationDisclosureBody,
      UsageLocalisation.arrierePlan => l10n.locationDisclosureBackgroundBody,
      UsageLocalisation.discussion => l10n.locationDisclosureChatBody,
    };

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kDesignRadius + 8),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
        // L'échelle de police du téléphone peut doubler la hauteur du texte :
        // la feuille défile plutôt que de déborder.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.outlineColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 26,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                corps,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _LienPolitique(
                  label: l10n.locationDisclosureReadPolicy,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              DesignPillButton(
                label: l10n.locationDisclosureAccept,
                expand: true,
                showArrow: false,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
              DesignSecondaryButton(
                label: l10n.locationDisclosureDecline,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lien vers la politique de confidentialité.
///
/// La route `/settings/privacy` fait partie des chemins que le routeur laisse
/// passer sans redirection, y compris pendant l'onboarding : le lien reste
/// donc cliquable avant que le profil ne soit complet.
class _LienPolitique extends StatelessWidget {
  final String label;
  final double fontSize;

  const _LienPolitique({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/settings/privacy'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: context.adaptivePrimaryColor,
            decoration: TextDecoration.underline,
            decorationColor: context.adaptivePrimaryColor,
          ),
        ),
      ),
    );
  }
}
