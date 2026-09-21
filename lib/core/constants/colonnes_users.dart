/// Colonnes de `public.users` qu'un compte peut lire chez **autrui**.
///
/// C'est la liste du `GRANT SELECT` de la fermeture 1.1b de l'audit
/// pré-production (`supabase/users-colonnes-privees-cible.sql`), à la colonne
/// près. Tant que cette cible n'est pas appliquée, les autres colonnes restent
/// lisibles ; une fois appliquée, toute requête PostgREST qui en touche une —
/// `select()` nu, filtre, tri, `RETURNING *` — est refusée **entière** en
/// 42501. C'est pourquoi l'app ne lit plus `users` qu'avec cette liste.
///
/// Ce qui n'y est pas, et où le trouver :
///
/// - sa **propre** ligne entière (e-mail, téléphone, session, jetons…) :
///   RPC `mon_profil_prive()` ;
/// - la **position** d'autrui, consentement appliqué par le serveur :
///   `positions_partagees()` (par boîte) et `positions_partagees_par_ids()` ;
/// - le **back-office** : `profils_admin()` ;
/// - le **jeton push** : `ajouter_jeton_push()` / `retirer_jeton_push()`, sans
///   jamais le relire.
///
/// `test/core/users_colonnes_privees_test.dart` vérifie que cette liste est
/// identique au `GRANT` de la cible, et balaie `lib/` pour qu'aucune lecture
/// de `users` n'en sorte. Ajouter une colonne ici sans l'ajouter à la cible
/// fait échouer ce test — c'est voulu : la seconde casserait l'app le jour de
/// l'application.
library;

/// Les 46 colonnes accordées, dans l'ordre du `GRANT`.
const List<String> colonnesPubliquesUsers = [
  'id', 'firebase_uid', 'display_name', 'display_name_lower', 'handle',
  'avatar_url', 'bio', 'profession', 'country_code', 'city', 'ville_id',
  'current_region', 'origin_region', 'origin_city',
  'is_private', 'is_visible', 'is_verified', 'is_admin', 'is_banned',
  'follower_count', 'following_count', 'post_count',
  'connections_count', 'groups_count', 'events_count',
  'interests', 'skills', 'languages',
  'is_online', 'last_seen_at', 'last_active_at', 'show_online_status',
  'share_location', 'phone_visibility', 'is_phone_verified',
  'notifications_enabled', 'notify_local_events', 'show_message_preview',
  'notification_prefs',
  'has_seen_onboarding', 'has_seen_coach_marks', 'has_given_consent',
  'consent_date', 'profile_config_complete',
  'created_at', 'updated_at',
];

/// La même liste, prête pour `.select(...)`.
///
/// Sans espaces : PostgREST les tolère, mais une URL plus courte est une URL
/// de moins à déboguer.
final String selectPublicUsers = colonnesPubliquesUsers.join(',');
