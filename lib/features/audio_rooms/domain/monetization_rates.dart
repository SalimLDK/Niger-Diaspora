/// Taux de commission de la plateforme sur les salons audio.
///
/// **Le serveur fait foi.** Cette constante doit rester égale à
/// `PLATFORM_COMMISSION_RATE` des Edge Functions `process-tip` et
/// `process-room-ticket` (`supabase/functions/`), qui sont les seules à
/// calculer et stocker le montant réellement prélevé. Le client ne l'utilise
/// que pour *annoncer* la part du créateur avant paiement.
///
/// Historique : trois valeurs coexistaient sans se rencontrer — 5 % affiché
/// dans les feuilles d'achat et de pourboire, 15 % ou 20 % selon l'entité, et
/// 15 % côté serveur. Les feuilles promettaient donc 95 % au créateur pour un
/// prélèvement réel de 15 %.
const double kAudioRoomsCommissionRate = 0.15;

/// Part nette du créateur, en pourcentage entier, pour l'affichage.
int get kAudioRoomsCreatorSharePercent =>
    ((1 - kAudioRoomsCommissionRate) * 100).round();
