/// Grain de partage de la position sur la carte.
///
/// La position d'un membre est PUBLIÉE arrondie à ce grain : la carte montre un
/// quartier, jamais le bâtiment. C'est ce qui rend vraie la promesse
/// « position approximative, jamais l'adresse exacte » (accueil, onboarding),
/// quelle que soit la précision du capteur GPS.
///
/// 3 décimales ≈ 111 m de latitude (~108 m de longitude vers Niamey) : une
/// cellule contient plusieurs adresses, donc aucune n'est identifiable, tout en
/// gardant utile la carte « membres à moins de 5 km ».
///
/// L'arrondi est appliqué au SEUL point d'écriture de `users.latitude` /
/// `users.longitude` — `ProfileSupabaseDataSource.updateLocation` — par où
/// passent les deux publieurs (l'avant-plan `LocationPublisherService` et le
/// service d'arrière-plan). Ni la précision du capteur ni un futur appelant ne
/// peut donc le contourner. La position que l'utilisateur voit de LUI-MÊME
/// (centrage de la carte, recherche des membres proches) vient de son appareil,
/// pas de cette valeur : seul le PARTAGE est arrondi.
double arrondirPositionPartagee(double coordonnee) {
  const double facteur = 1000; // 10^3 → 3 décimales
  return (coordonnee * facteur).roundToDouble() / facteur;
}
