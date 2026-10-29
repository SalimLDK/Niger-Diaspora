# Console Diaspo Niger (back-office web)

Application web d'administration, **distincte** du panneau Flutter (`lib/features/admin`).
React 19 · TypeScript · Vite · Tailwind 4 · TanStack Query · React Router.

Elle ne crée aucune seconde base : elle parle au backend existant.

- **Identité** : Firebase Auth (e-mail + mot de passe) puis **TOTP obligatoire**. Un compte sans TOTP
  est forcé de l'enrôler ; un jeton sans second facteur est refusé.
- **Données** : Supabase. Le jeton Firebase est échangé contre une session Supabase par l'Edge Function
  `auth-firebase-exchange` (la même que l'application).
- **Autorisation** : uniquement côté serveur. La console lit `admin_has_permission` pour **afficher**
  ou masquer le menu ; toute écriture passe par une fonction serveur (`signalement_transition`,
  `support_ticket_reply`, `campaign_review`…) qui revérifie droit, état courant, motif et audit.

## Lancer

```bash
cd backoffice
npm install
cp .env.example .env.local     # puis renseigner les 6 variables (clés publiques du client)
npm run dev                    # http://localhost:5180  (localhost, pas 127.0.0.1 : domaine autorisé Firebase)
npm run typecheck && npm test && npm run build
```

`.env.local` est ignoré par git. Les clés `VITE_*` sont embarquées dans le JavaScript : n'y mettre que
des clés **publiques** (clé web Firebase, clé `anon` Supabase), jamais de clé de service.

## Modules

Vue générale · Statistiques · Membres · Signalements (dossier, demandes d'informations, recours) ·
Groupes · Campagnes (validation) · Démarches consulaires (relecture, publication) · Support ·
Événements · Ambassades · Annuaire · Confidentialité · Incidents · Rôles et permissions · Journal d'audit.

Transverse : modèles de réponse du support, escalade, historique des signalements d'un membre, alerte « N urgents » dans l'en-tête (rafraîchie chaque minute), thème sombre, pages à chargement différé, recherche globale, tri par colonne, recherche texte, export CSV (formules neutralisées),
export du journal par fonction serveur (inscrit lui-même au journal), menu réductible, déconnexion après
15 minutes d'inactivité.

## Ce qui n'est pas dans cette version

- Envoi effectif d'une campagne par lots (la console crée, soumet, valide et annule ; l'envoi reste côté panneau actuel).
- Rédaction du contenu d'une démarche consulaire (la console relit et publie).
- Paiements, boosts, salons audio : volontairement absents (chaîne fermée).
- Tests de bout en bout contre un faux serveur ; sont testés aujourd'hui les utilitaires purs et les états d'écran.
- Réglages : édition par JSON brut d'une section (pas de formulaire typé par réglage).

## Déploiement (à faire, rien n'est publié)

1. `npm run build` produit `dist/`.
2. Héberger sur un **site Firebase Hosting dédié** (ex. `diaspo-niger-console`), pas sur le site public.
   La configuration est prête : `firebase.console.json` (en-têtes CSP/HSTS inclus). Créer le site, puis
   `firebase hosting:sites:create diaspo-niger-console` et `firebase deploy --only hosting --config backoffice/firebase.console.json`
   **après accord explicite** : rien n'a été déployé.
   Ajouter le domaine à la liste des domaines autorisés de Firebase Auth.
3. En-têtes à poser au niveau Hosting (le build n'en met pas) :
   - `Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' https://*.supabase.co https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://www.googleapis.com; frame-ancestors 'none'; base-uri 'none'`
   - `Strict-Transport-Security: max-age=31536000; includeSubDomains`
   - `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`
   - réécriture `** → /index.html` (application monopage) ; `Cache-Control: no-cache` sur `index.html`.
4. Retour arrière : redéployer la version précédente depuis l'historique Hosting.
5. Avant d'ouvrir à l'équipe : recette par rôle (voir le cahier des charges v1.2, § 11) sur un compte de
   chaque rôle, en vérifiant au moins trois refus par action.
