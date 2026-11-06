/** Jeu de données INVENTÉ pour le mode démo. Aucun nom, e-mail ou identifiant ne désigne une vraie personne. */

export type Ligne = Record<string, unknown>
export interface DonneesDemo {
  tables: Record<string, Ligne[]>
  reglages: Record<string, Record<string, unknown>>
  historique: { id: string; section: string; before: Record<string, unknown> | null; after: Record<string, unknown> | null; by: string; at: string; kind: string; reason?: string }[]
}

const il = (jours: number, heures = 0) => new Date(Date.now() - jours * 86_400_000 - heures * 3_600_000).toISOString()
const dans = (jours: number) => new Date(Date.now() + jours * 86_400_000).toISOString()

const PRENOMS = ['Aïssata', 'Moussa', 'Fatouma', 'Ibrahim', 'Zara', 'Abdou', 'Mariama', 'Harouna', 'Salamatou', 'Issoufou', 'Rakia', 'Souleymane',
  'Hadiza', 'Boubacar', 'Nafissa', 'Oumarou', 'Aminata', 'Idrissa', 'Safiatou', 'Mahamadou']
const LIEUX: [string, string][] = [['Niger', 'Niamey'], ['France', 'Paris'], ['Canada', 'Montréal'], ['Belgique', 'Bruxelles'], ['Côte d\'Ivoire', 'Abidjan'],
  ['États-Unis', 'Washington'], ['Allemagne', 'Berlin'], ['Niger', 'Zinder'], ['France', 'Lyon'], ['Canada', 'Ottawa']]

function membres(): Ligne[] {
  return PRENOMS.map((p, i) => {
    const [pays, ville] = LIEUX[i % LIEUX.length]
    return {
      id: `demo-u${i + 1}`, display_name: `${p} (démo ${i + 1})`, email: `membre${i + 1}@exemple.test`, country_code: pays, city: ville,
      created_at: il(5 + i * 9), last_active_at: il(i % 4 === 0 ? 0 : i, i), is_banned: i === 6, is_verified: i % 5 === 0,
      admin_role: null, is_admin: false, is_private: i % 3 === 0,
    }
  })
}

export function creerDonnees(): DonneesDemo {
  const users = [
    { id: 'demo-admin', display_name: 'Compte de démonstration', email: 'demo@exemple.test', country_code: 'Niger', city: 'Niamey',
      created_at: il(400), last_active_at: il(0), is_banned: false, is_verified: true, admin_role: 'superAdmin', is_admin: true, is_private: false },
    { id: 'demo-a2', display_name: 'Modératrice (démo)', email: 'moderation@exemple.test', country_code: 'France', city: 'Paris',
      created_at: il(300), last_active_at: il(1), is_banned: false, is_verified: false, admin_role: 'contentMod', is_admin: true, is_private: false },
    { id: 'demo-a3', display_name: 'Auditeur (démo)', email: 'audit@exemple.test', country_code: 'Canada', city: 'Montréal',
      created_at: il(200), last_active_at: il(2), is_banned: false, is_verified: false, admin_role: 'auditor', is_admin: true, is_private: false },
    ...membres(),
  ]

  const perms: [string, string, string][] = [
    ['dashboard.view', 'dashboard', 'Voir le tableau de bord'], ['dashboard.analytics.view', 'dashboard', 'Voir les statistiques'],
    ['community.members.view', 'community', 'Voir les membres'], ['community.members.contact', 'community', 'Contacter un membre'],
    ['community.groups.manage', 'community', 'Modérer les groupes'], ['moderation.reports.view', 'moderation', 'Voir les signalements'],
    ['moderation.reports.review', 'moderation', 'Traiter les signalements'], ['support.tickets.view', 'support', 'Voir les tickets'],
    ['support.tickets.reply', 'support', 'Répondre aux tickets'], ['support.templates.manage', 'support', 'Gérer les modèles de réponse'],
    ['directory.listings.view', 'directory', 'Voir les fiches'], ['directory.listings.approve', 'directory', 'Vérifier une fiche'],
    ['consular.procedures.approve', 'consular', 'Approuver une démarche'], ['consular.embassies.verify', 'consular', 'Vérifier un poste'],
    ['communications.view', 'communications', 'Voir les campagnes'], ['communications.send', 'communications', 'Envoyer une campagne'],
    ['privacy.requests.manage', 'privacy', 'Traiter les demandes de données'], ['security.incidents.manage', 'security', 'Gérer les incidents'],
    ['security.audit.view', 'security', "Voir le journal d'audit"], ['security.audit.export', 'security', "Exporter le journal d'audit"],
    ['security.admins.promote', 'security', 'Inviter des administrateurs'], ['security.roles.manage', 'security', 'Voir les rôles'],
    ['settings.general.view', 'settings', 'Voir les réglages'], ['events.attendance.view', 'events', 'Voir les événements'],
  ]
  const roleDroits: [string, string][] = [
    ['contentMod', 'dashboard.view'], ['contentMod', 'community.members.view'], ['contentMod', 'community.members.contact'],
    ['contentMod', 'community.groups.manage'], ['contentMod', 'moderation.reports.view'], ['contentMod', 'moderation.reports.review'],
    ['contentMod', 'support.tickets.view'], ['contentMod', 'support.tickets.reply'], ['contentMod', 'security.audit.view'],
    ['auditor', 'dashboard.view'], ['auditor', 'security.audit.view'], ['auditor', 'security.audit.export'],
    ['supportAgent', 'dashboard.view'], ['supportAgent', 'support.tickets.view'], ['supportAgent', 'support.tickets.reply'],
    ['validator', 'dashboard.view'], ['validator', 'consular.procedures.approve'], ['validator', 'consular.embassies.verify'],
    ['analyst', 'dashboard.view'], ['analyst', 'dashboard.analytics.view'],
  ]

  const messageSupport = (txt: string, h: number) => ({ id: `m${h}`, senderName: 'Support Diaspo Niger', isFromSupport: true, content: txt, createdAt: il(0, h) })
  const messageMembre = (txt: string, h: number, nom: string) => ({ id: `u${h}`, senderName: nom, isFromSupport: false, content: txt, createdAt: il(0, h) })

  return {
    tables: {
      users,
      admin_permissions: perms.map(([key, module, description]) => ({ key, module, description })),
      admin_role_permissions: roleDroits.map(([role, permission]) => ({ role, permission })),
      reports: [
        { id: 'demo-r1', reporter_id: 'demo-u3', target_type: 'post', target_id: 'demo-p1', reason: 'spam', description: 'Publication répétée avec un lien suspect (exemple fictif).', status: 'pending', assigned_to: null, reason_code: null, admin_note: null, created_at: il(0, 3) },
        { id: 'demo-r2', reporter_id: 'demo-u5', target_type: 'user', target_id: 'demo-u9', reason: 'harcèlement', description: 'Messages insistants après un refus (exemple fictif).', status: 'pending', assigned_to: null, reason_code: null, admin_note: null, created_at: il(1) },
        { id: 'demo-r3', reporter_id: 'demo-u2', target_type: 'business', target_id: 'demo-b3', reason: 'fraude', description: 'Annonce de service qui ne correspond pas à la fiche (exemple fictif).', status: 'reviewing', assigned_to: 'demo-admin', reason_code: null, admin_note: null, created_at: il(2) },
        { id: 'demo-r4', reporter_id: 'demo-u7', target_type: 'comment', target_id: 'demo-c1', reason: 'contenu inapproprié', description: null, status: 'escalated', assigned_to: 'demo-a2', reason_code: 'high_risk', admin_note: 'À valider par un second responsable.', created_at: il(4) },
        { id: 'demo-r5', reporter_id: 'demo-u4', target_type: 'post', target_id: 'demo-p7', reason: 'spam', description: null, status: 'resolved', assigned_to: 'demo-a2', reason_code: 'content_removed', admin_note: 'Contenu retiré.', created_at: il(9) },
      ],
      moderation_report_transitions: [
        { from_status: 'pending', to_status: 'reviewing', permission: 'moderation.reports.assign', needs_reason: false, needs_note: false, needs_action: false },
        { from_status: 'pending', to_status: 'dismissed', permission: 'moderation.reports.review', needs_reason: true, needs_note: true, needs_action: false },
        { from_status: 'reviewing', to_status: 'resolved', permission: 'moderation.reports.review', needs_reason: true, needs_note: true, needs_action: true },
        { from_status: 'reviewing', to_status: 'dismissed', permission: 'moderation.reports.review', needs_reason: true, needs_note: true, needs_action: false },
        { from_status: 'reviewing', to_status: 'escalated', permission: 'moderation.reports.escalate', needs_reason: true, needs_note: true, needs_action: false },
        { from_status: 'escalated', to_status: 'resolved', permission: 'moderation.reports.review', needs_reason: true, needs_note: true, needs_action: true },
        { from_status: 'escalated', to_status: 'dismissed', permission: 'moderation.reports.review', needs_reason: true, needs_note: true, needs_action: false },
      ],
      moderation_info_requests: [
        { id: 'demo-i1', report_id: 'demo-r3', recipient_kind: 'reporter', questions: 'Pouvez-vous préciser la date de l\'annonce concernée ?', due_at: dans(3), status: 'sent', response: null, sent_at: il(1), created_at: il(1) },
      ],
      moderation_appeals: [],
      support_tickets: [
        { id: 'demo-t1', subject: 'Je ne reçois plus les notifications', status: 'open', priority: 'normal', category: 'technical', assigned_to: null, created_at: il(0, 5), updated_at: il(0, 5), description: 'Depuis hier plus rien (exemple fictif).', user_name: 'Hadiza (démo 13)', messages: [messageMembre('Depuis hier je ne reçois plus rien.', 5, 'Hadiza')], resolution_note: null },
        { id: 'demo-t2', subject: 'Changer ma ville de résidence', status: 'in_progress', priority: 'normal', category: 'account', assigned_to: 'demo-admin', created_at: il(1), updated_at: il(0, 8), description: 'Je suis arrivé à Lyon (exemple fictif).', user_name: 'Boubacar (démo 14)', messages: [messageMembre('Comment changer ma ville ?', 30, 'Boubacar'), messageSupport('Bonjour, cela se fait depuis votre profil, dans les paramètres.', 8)], resolution_note: null },
        { id: 'demo-t3', subject: 'Compte suspendu : contestation', status: 'in_progress', priority: 'high', category: 'account', assigned_to: 'demo-a2', created_at: il(3), updated_at: il(2), description: 'Je conteste (exemple fictif).', user_name: 'Souleymane (démo 12)', messages: [], resolution_note: null },
        { id: 'demo-t4', subject: 'Question sur une démarche consulaire', status: 'resolved', priority: 'normal', category: 'other', assigned_to: 'demo-admin', created_at: il(7), updated_at: il(6), description: '', user_name: 'Rakia (démo 11)', messages: [], resolution_note: 'Orientée vers le consulat.' },
      ],
      support_ticket_transitions: [
        { from_status: 'open', to_status: 'in_progress', permission: 'support.tickets.assign', needs_note: false },
        { from_status: 'in_progress', to_status: 'resolved', permission: 'support.tickets.reply', needs_note: true },
        { from_status: 'in_progress', to_status: 'closed', permission: 'support.tickets.close', needs_note: true },
        { from_status: 'resolved', to_status: 'closed', permission: 'support.tickets.close', needs_note: true },
        { from_status: 'resolved', to_status: 'in_progress', permission: 'support.tickets.assign', needs_note: true },
      ],
      support_reply_templates: [
        { id: 'demo-m1', title: 'Accusé de réception', category: 'other', body: 'Bonjour [prénom],\n\nNous avons bien reçu votre demande. Un membre de l\'équipe la prend en charge et reviendra vers vous.\n\nCordialement,\nL\'équipe Diaspo Niger' },
        { id: 'demo-m2', title: 'Notifications absentes : vérifications', category: 'technical', body: 'Bonjour [prénom],\n\nVérifiez que les notifications sont autorisées dans les réglages de votre téléphone et que l\'économie de batterie ne restreint pas l\'application.\n\nCordialement,\nL\'équipe Diaspo Niger' },
        { id: 'demo-m3', title: 'Clôture : problème résolu', category: 'other', body: 'Bonjour [prénom],\n\nNous considérons votre demande comme résolue. Répondez à ce message si le problème réapparaît.\n\nCordialement,\nL\'équipe Diaspo Niger' },
      ],
      events: [
        { id: 'demo-e1', title: 'Rencontre de la diaspora — Paris', status: 'upcoming', city: 'Paris', country_code: 'France', starts_at: dans(12), attendee_count: 48, is_online: false },
        { id: 'demo-e2', title: 'Atelier démarches consulaires (en ligne)', status: 'upcoming', city: null, country_code: null, starts_at: dans(5), attendee_count: 120, is_online: true },
        { id: 'demo-e3', title: 'Tournoi amical — Montréal', status: 'draft', city: 'Montréal', country_code: 'Canada', starts_at: dans(30), attendee_count: 0, is_online: false },
        { id: 'demo-e4', title: 'Fête de l\'indépendance — Bruxelles', status: 'ended', city: 'Bruxelles', country_code: 'Belgique', starts_at: il(40), attendee_count: 210, is_online: false },
      ],
      businesses: [
        { id: 'demo-b1', name: 'Épicerie du Sahel (démo)', name_lower: 'épicerie du sahel (démo)', category: 'Alimentation', city: 'Paris', country_code: 'France', is_verified: true, is_active: true, created_at: il(120) },
        { id: 'demo-b2', name: 'Transport Express Niamey (démo)', name_lower: 'transport express niamey (démo)', category: 'Transport', city: 'Niamey', country_code: 'Niger', is_verified: false, is_active: true, created_at: il(15) },
        { id: 'demo-b3', name: 'Coiffure Zara (démo)', name_lower: 'coiffure zara (démo)', category: 'Beauté', city: 'Lyon', country_code: 'France', is_verified: false, is_active: true, created_at: il(8) },
        { id: 'demo-b4', name: 'Fiche archivée (démo)', name_lower: 'fiche archivée (démo)', category: 'Autre', city: 'Ottawa', country_code: 'Canada', is_verified: false, is_active: false, created_at: il(200) },
      ],
      groups: [
        { id: 'demo-g1', name: 'Diaspora nigérienne — Officiel', category: 'Communauté', country_code: 'Niger', is_private: false, member_count: 1240, created_at: il(380) },
        { id: 'demo-g2', name: 'Étudiants à Montréal', category: 'Études', country_code: 'Canada', is_private: true, member_count: 86, created_at: il(150) },
        { id: 'demo-g3', name: 'Entrepreneurs de la diaspora', category: 'Emploi', country_code: 'France', is_private: false, member_count: 312, created_at: il(90) },
      ],
      embassies: [
        { id: 'demo-p1', name: 'Ambassade du Niger — Paris (démo)', type: 'embassy', country: 'France', city: 'Paris', is_verified: true, is_suspended: false, source_url: 'https://exemple.test/ambassade-paris' },
        { id: 'demo-p2', name: 'Consulat du Niger — Montréal (démo)', type: 'consulate', country: 'Canada', city: 'Montréal', is_verified: false, is_suspended: false, source_url: null },
        { id: 'demo-p3', name: 'Poste en travaux (démo)', type: 'consulate', country: 'Belgique', city: 'Bruxelles', is_verified: true, is_suspended: true, source_url: 'https://exemple.test/poste' },
      ],
      campaigns: [
        { id: 'demo-c1', type: 'official_info', title: 'Maintenance prévue ce week-end', body: 'L\'application sera brièvement indisponible dimanche matin pour une mise à jour.', status: 'pending_approval', review_note: null, created_at: il(0, 6), sent_at: null },
        { id: 'demo-c2', type: 'official_info', title: 'Nouvel annuaire des consulats', body: 'Retrouvez les postes diplomatiques vérifiés dans l\'onglet Annuaire.', status: 'approved', review_note: null, created_at: il(2), sent_at: null },
        { id: 'demo-c3', type: 'security', title: 'Conseils de sécurité du compte', body: 'Ne communiquez jamais votre mot de passe ni vos codes de connexion.', status: 'sent', review_note: null, created_at: il(14), sent_at: il(13) },
      ],
      demarches_brouillons: [
        { id: 'demo-d1', demarche_id: 'passeport-renouvellement', status: 'pending', change_reason: 'Nouveau tarif communiqué par le consulat', review_note: null, submitted_at: il(1), updated_at: il(1) },
        { id: 'demo-d2', demarche_id: 'acte-naissance', status: 'approved', change_reason: 'Ajout d\'une pièce justificative', review_note: 'Source vérifiée.', submitted_at: il(5), updated_at: il(3) },
        { id: 'demo-d3', demarche_id: 'carte-consulaire', status: 'draft', change_reason: 'Mise à jour des horaires', review_note: null, submitted_at: null, updated_at: il(0, 2) },
      ],
      privacy_requests: [
        { id: 'demo-q1', kind: 'access', status: 'received', due_at: dans(24), identity_verified_at: null, assigned_to: null, created_at: il(4) },
        { id: 'demo-q2', kind: 'erasure', status: 'in_progress', due_at: dans(10), identity_verified_at: il(5), assigned_to: 'demo-admin', created_at: il(20) },
      ],
      security_incidents: [
        { id: 'demo-s1', title: 'Pic de tentatives de connexion échouées', severity: 'medium', status: 'contained', detected_at: il(3), resolved_at: null },
        { id: 'demo-s2', title: 'Certificat expirant (exemple)', severity: 'low', status: 'resolved', detected_at: il(30), resolved_at: il(29) },
      ],
      admin_audit_logs: [
        { id: 'demo-l1', admin_id: 'demo-a2', admin_name: 'Modératrice (démo)', action: 'REPORT_ASSIGNED', target_type: 'report', target_id: 'demo-r3', result: 'success', reason_code: null, created_at: il(2) },
        { id: 'demo-l2', admin_id: 'demo-admin', admin_name: 'Compte de démonstration', action: 'TICKET_REPLIED', target_type: 'support_ticket', target_id: 'demo-t2', result: 'success', reason_code: null, created_at: il(0, 8) },
        { id: 'demo-l3', admin_id: 'demo-a3', admin_name: 'Auditeur (démo)', action: 'AUDIT_EXPORTED', target_type: 'audit', target_id: null, result: 'success', reason_code: null, created_at: il(6) },
      ],
      admin_invitations: [],
    },
    reglages: {
      general: { appName: 'Diaspo Niger', maintenance: false, minVersion: '1.2.0' },
      community: { maxGroupSize: 500, allowPublicGroups: true },
      moderation: { reportCooldownMinutes: 5, autoHideThreshold: 3 },
    },
    historique: [
      { id: 'demo-h1', section: 'moderation', before: { reportCooldownMinutes: 10, autoHideThreshold: 3 }, after: { reportCooldownMinutes: 5, autoHideThreshold: 3 },
        by: 'demo-admin', at: il(12), kind: 'update', reason: 'Réduire le délai entre deux signalements' },
    ],
  }
}
