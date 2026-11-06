/// Une photo Google arrive en 96 px (`…=s96-c`) : posée telle quelle comme
/// avatar, elle s'affiche en gros pixels dès qu'on l'ouvre ou qu'elle occupe
/// la fiche profil. Google sert la même image à la taille demandée.
///
/// Toute autre URL (Firebase Storage, Supabase…) est rendue inchangée.
String? agrandirPhotoGoogle(String? url, {int taille = 512}) {
  if (url == null || !url.contains('googleusercontent.com')) return url;
  return url.replaceFirst(RegExp(r'=s\d+(-c)?$'), '=s$taille-c');
}
