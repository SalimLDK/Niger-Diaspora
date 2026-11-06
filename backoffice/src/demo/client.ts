import { creerDonnees, type DonneesDemo, type Ligne } from './donnees'
import { IDENTITE_DEMO } from './etat'

/** Données vivantes du mode démo : recréées à chaque entrée, jamais persistées. */
let base: DonneesDemo = creerDonnees()
export const reinitialiserDemo = (): void => { base = creerDonnees() }
export const donneesDemo = (): DonneesDemo => base

const sleep = () => new Promise<void>((r) => setTimeout(r, 120))   // un soupçon de latence : l'écran passe par « Chargement… »
const alea = () => Math.random().toString(36).slice(2, 10)

export class ErreurDemo extends Error {
  code: string
  constructor(code: string, message: string) {
    super(message)
    this.code = code
  }
}

/* ------------------------------------------------------------------ requêtes */

const motif = (m: string) => new RegExp('^' + m.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/%/g, '.*') + '$', 'i')

type Filtre = (r: Ligne) => boolean

function filtreOu(expr: string): Filtre {
  const parts = expr.split(',').map((t) => {
    const [col, op, ...reste] = t.split('.')
    const val = reste.join('.')
    return (r: Ligne): boolean => {
      const v = r[col]
      if (op === 'is') return val === 'null' ? v === null || v === undefined : String(v) === val
      if (op === 'ilike') return motif(val).test(String(v ?? ''))
      return String(v) === val
    }
  })
  return (r) => parts.some((f) => f(r))
}

class Requete implements PromiseLike<{ data: unknown; error: ErreurDemo | null; count: number | null }> {
  private lignes: Ligne[]
  private filtres: Filtre[] = []
  private tri: { col: string; asc: boolean } | null = null
  private debut = 0
  private fin = Infinity
  private cols: string[] | null = null
  private compte = false
  private tete = false
  private unique = false

  constructor(table: string) {
    this.lignes = base.tables[table] ?? []
  }

  select(cols = '*', opts?: { count?: string; head?: boolean }) {
    this.cols = cols === '*' ? null : cols.split(',').map((c) => c.trim())
    this.compte = Boolean(opts?.count)
    this.tete = Boolean(opts?.head)
    return this
  }
  order(col: string, opts?: { ascending?: boolean }) { this.tri = { col, asc: opts?.ascending !== false }; return this }
  range(a: number, b: number) { this.debut = a; this.fin = b + 1; return this }
  limit(n: number) { this.fin = this.debut + n; return this }
  eq(col: string, val: unknown) { this.filtres.push((r) => String(r[col]) === String(val)); return this }
  in(col: string, vals: unknown[]) { this.filtres.push((r) => vals.map(String).includes(String(r[col]))); return this }
  gte(col: string, val: unknown) { this.filtres.push((r) => String(r[col] ?? '') >= String(val)); return this }
  lte(col: string, val: unknown) { this.filtres.push((r) => String(r[col] ?? '') <= String(val)); return this }
  ilike(col: string, m: string) { this.filtres.push((r) => motif(m).test(String(r[col] ?? ''))); return this }
  not(col: string, op: string, val: unknown) {
    if (op === 'is' && val === null) this.filtres.push((r) => r[col] !== null && r[col] !== undefined)
    return this
  }
  or(expr: string) { this.filtres.push(filtreOu(expr)); return this }
  single() { this.unique = true; return this }

  private executer() {
    let rows = this.lignes.filter((r) => this.filtres.every((f) => f(r)))
    const total = rows.length
    if (this.tri) {
      const { col, asc } = this.tri
      rows = [...rows].sort((a, b) => {
        const x = a[col] as never, y = b[col] as never
        if (x === y) return 0
        if (x === null || x === undefined) return 1
        if (y === null || y === undefined) return -1
        return (x > y ? 1 : -1) * (asc ? 1 : -1)
      })
    }
    rows = rows.slice(this.debut, this.fin)
    const cols = this.cols
    const projet = cols ? rows.map((r) => Object.fromEntries(cols.map((c) => [c, r[c]]))) : rows.map((r) => ({ ...r }))
    if (this.unique) {
      return projet[0]
        ? { data: projet[0], error: null, count: null }
        : { data: null, error: new ErreurDemo('PGRST116', 'Aucune ligne (démo)'), count: null }
    }
    return { data: this.tete ? null : projet, error: null, count: this.compte ? total : null }
  }

  then<A, B>(ok?: ((v: { data: unknown; error: ErreurDemo | null; count: number | null }) => A | PromiseLike<A>) | null,
             ko?: ((e: unknown) => B | PromiseLike<B>) | null): Promise<A | B> {
    return sleep().then(() => this.executer()).then(ok, ko)
  }
}

/* ---------------------------------------------------------------------- RPC */

const ligne = (table: string, id: unknown, col = 'id'): Ligne => {
  const l = (base.tables[table] ?? []).find((r) => String(r[col]) === String(id))
  if (!l) throw new ErreurDemo('P0002', 'Introuvable (démo)')
  return l
}

function audit(action: string, type: string, cible: unknown, motifCode: string | null = null): void {
  base.tables.admin_audit_logs.unshift({
    id: `demo-l${alea()}`, admin_id: IDENTITE_DEMO.id, admin_name: IDENTITE_DEMO.nom, action, target_type: type,
    target_id: cible === null || cible === undefined ? null : String(cible), result: 'success', reason_code: motifCode, created_at: new Date().toISOString(),
  })
}

const exiger = (v: unknown, nom: string, min = 1): string => {
  const s = String(v ?? '').trim()
  if (s.length < min) throw new ErreurDemo('22023', `${nom} requis (démo)`)
  return s
}

/** Change le statut d'une ligne et journalise : la forme commune des actions de la console. */
const changer = (table: string, id: unknown, patch: Ligne, action: string, type: string, code: string | null = null) => {
  Object.assign(ligne(table, id), patch)
  audit(action, type, id, code)
  return null
}

const compter = (table: string, f: Filtre = () => true) => (base.tables[table] ?? []).filter(f).length
const masque = (e: unknown) => /^(.)[^@]*@(.)[^@]*(\.[^.@]+)$/.exec(String(e ?? '')) ? String(e).replace(/^(.)[^@]*@(.)[^@]*(\.[^.@]+)$/, '$1•••@$2•••$3') : null

type Args = Record<string, unknown>
const RPC: Record<string, (a: Args) => unknown> = {
  admin_has_permission: () => true,

  admin_dashboard_tasks: () => {
    const T = base.tables
    const age = (rows: Ligne[], col: string) => rows.map((r) => String(r[col])).sort()[0] ?? null
    const ouv = (t: string, st: string[]) => T[t].filter((r) => st.includes(String(r.status)))
    const items = [
      { key: 'reports', rows: ouv('reports', ['pending', 'reviewing', 'escalated']), col: 'created_at' },
      { key: 'support', rows: ouv('support_tickets', ['open', 'in_progress']), col: 'created_at' },
      { key: 'demarches', rows: ouv('demarches_brouillons', ['pending', 'approved']), col: 'updated_at' },
      { key: 'campaigns', rows: ouv('campaigns', ['pending_approval']), col: 'created_at' },
      { key: 'privacy', rows: ouv('privacy_requests', ['received', 'identity_verified', 'in_progress']), col: 'created_at' },
      { key: 'incidents', rows: T.security_incidents.filter((r) => r.status !== 'closed'), col: 'detected_at' },
      { key: 'listings', rows: T.businesses.filter((r) => r.is_active && !r.is_verified), col: 'created_at' },
    ].map((x) => ({ key: x.key, count: x.rows.length, urgent: x.key === 'reports' ? x.rows.filter((r) => r.status === 'escalated').length : 0, oldest_at: age(x.rows, x.col) }))
    return { computed_at: new Date().toISOString(), items }
  },

  admin_stats: () => {
    const U = base.tables.users
    const jours = Array.from({ length: 30 }, (_, i) => {
      const d = new Date(Date.now() - (29 - i) * 86_400_000)
      const cle = d.toISOString().slice(0, 10)
      return { day: cle, n: U.filter((u) => String(u.created_at).slice(0, 10) === cle).length + ((i * 7) % 4) }
    })
    const pays = new Map<string, number>()
    U.forEach((u) => pays.set(String(u.country_code), (pays.get(String(u.country_code)) ?? 0) + 1))
    return {
      computed_at: new Date().toISOString(), users_total: U.length * 40 + 12, users_active_24h: U.length * 6, users_active_7d: U.length * 17,
      users_banned: compter('users', (u) => Boolean(u.is_banned)), groups: compter('groups'), events_upcoming: compter('events', (e) => e.status === 'upcoming'),
      businesses_active: compter('businesses', (b) => Boolean(b.is_active)), reports_open: compter('reports', (r) => ['pending', 'reviewing', 'escalated'].includes(String(r.status))),
      tickets_open: compter('support_tickets', (t) => ['open', 'in_progress'].includes(String(t.status))), signups_30d: jours,
      top_countries: [...pays.entries()].sort((a, b) => b[1] - a[1]).map(([country, n]) => ({ country, n: n * 9 })),
    }
  },

  admin_global_search: (a) => {
    const q = String(a.p_query ?? '').toLowerCase()
    const groupes = [
      { kind: 'members', items: base.tables.users.filter((u) => String(u.display_name).toLowerCase().includes(q)).slice(0, 6).map((u) => ({ id: u.id, title: u.display_name, subtitle: u.city, status: null })) },
      { kind: 'tickets', items: base.tables.support_tickets.filter((t) => String(t.subject).toLowerCase().includes(q)).slice(0, 6).map((t) => ({ id: t.id, title: t.subject, subtitle: t.user_name, status: t.status })) },
      { kind: 'events', items: base.tables.events.filter((e) => String(e.title).toLowerCase().includes(q)).slice(0, 6).map((e) => ({ id: e.id, title: e.title, subtitle: e.city, status: e.status })) },
    ].filter((g) => g.items.length > 0)
    return { groups: groupes, searched: ['members', 'tickets', 'events'] }
  },

  profils_admin_page: (a) => base.tables.users.filter((u) => (a.p_filtre === 'admins' ? u.is_admin : true)),

  admin_member_search: (a) => {
    const t = exiger(a.p_term, 'Terme', 3).toLowerCase()
    return base.tables.users
      .filter((u) => !u.is_banned && (String(u.display_name).toLowerCase().startsWith(t) || String(u.email).toLowerCase().startsWith(t)))
      .slice(0, 10)
      .map((u) => ({ id: u.id, display_name: u.display_name, email_masked: masque(u.email), created_at: u.created_at, is_admin: u.is_admin, admin_role: u.admin_role }))
  },

  /* invitations d'administrateurs */
  admin_invitation_list: () => base.tables.admin_invitations.map((i) => {
    const m = base.tables.users.find((u) => u.id === i.invitee_id)
    return { ...i, invitee_name: m?.display_name ?? null, invitee_email_masked: masque(m?.email), invited_by_name: IDENTITE_DEMO.nom, approved_by_name: i.approved ? 'Second super-administrateur (démo)' : null }
  }),
  admin_invitation_create: (a) => {
    const m = ligne('users', a.p_member_id)
    if (base.tables.admin_invitations.some((i) => i.invitee_id === m.id && ['pending', 'pending_approval'].includes(String(i.status)))) {
      throw new ErreurDemo('55000', 'invitation : une invitation est déjà en cours pour cette personne')
    }
    const id = `demo-inv${alea()}`
    base.tables.admin_invitations.unshift({
      id, invitee_id: m.id, role: a.p_role, status: a.p_role === 'superAdmin' ? 'pending_approval' : 'pending',
      expires_at: new Date(Date.now() + 7 * 86_400_000).toISOString(), created_at: new Date().toISOString(), decided_at: null,
    })
    audit('ADMIN_INVITED', 'user', m.id, String(a.p_role))
    return id
  },
  admin_invitation_approve: (a) => changer('admin_invitations', a.p_id, { status: 'pending', approved: true }, 'ADMIN_INVITATION_APPROVED', 'user'),
  admin_invitation_revoke: (a) => changer('admin_invitations', a.p_id, { status: 'revoked', decided_at: new Date().toISOString() }, 'ADMIN_INVITATION_REVOKED', 'user'),
  admin_invitation_mine: () => [],
  admin_invitation_decline: () => null,

  /* modération */
  signalement_transition: (a) => {
    const r = ligne('reports', a.p_report_id)
    const t = base.tables.moderation_report_transitions.find((x) => x.from_status === r.status && x.to_status === a.p_to)
    if (!t) throw new ErreurDemo('55000', `signalement : passage ${String(r.status)} → ${String(a.p_to)} impossible`)
    if (t.needs_reason) exiger(a.p_reason_code, 'Motif normalisé')
    if (t.needs_note) exiger(a.p_note, 'Justification')
    if (t.needs_action) exiger(a.p_action_taken, 'Mesure appliquée')
    Object.assign(r, { status: a.p_to, reason_code: a.p_reason_code ?? r.reason_code, admin_note: a.p_note ?? r.admin_note, assigned_to: IDENTITE_DEMO.id })
    audit('REPORT_' + String(a.p_to).toUpperCase(), 'report', r.id, String(a.p_reason_code ?? ''))
    return a.p_to
  },
  moderation_info_request_create: (a) => {
    const id = `demo-i${alea()}`
    base.tables.moderation_info_requests.unshift({ id, report_id: a.p_report_id, recipient_kind: a.p_recipient_kind, questions: exiger(a.p_questions, 'Questions', 5), due_at: a.p_due_at, status: 'draft', response: null, sent_at: null, created_at: new Date().toISOString() })
    audit('INFO_REQUEST_CREATED', 'report', a.p_report_id)
    return id
  },
  moderation_info_request_send: (a) => changer('moderation_info_requests', a.p_id, { status: 'sent', sent_at: new Date().toISOString() }, 'INFO_REQUEST_SENT', 'report'),
  moderation_appeal_take: (a) => changer('moderation_appeals', a.p_id, { status: 'in_review' }, 'APPEAL_TAKEN', 'report'),
  moderation_appeal_decide: (a) => changer('moderation_appeals', a.p_id, { status: a.p_outcome, decision_note: exiger(a.p_note, 'Motivation') }, 'APPEAL_DECIDED', 'report', String(a.p_outcome)),

  /* membres */
  member_admin_warn: (a) => { exiger(a.p_message, 'Message', 10); audit('MEMBER_WARNED', 'user', a.p_id); return 1 },
  member_admin_force_logout: (a) => { exiger(a.p_reason, 'Motif', 5); audit('MEMBER_FORCE_LOGOUT', 'user', a.p_id); return null },
  member_admin_contact: (a) => {
    const m = ligne('users', a.p_member_id)
    const id = `demo-t${alea()}`
    base.tables.support_tickets.unshift({
      id, subject: exiger(a.p_subject, 'Sujet', 5), status: 'in_progress', priority: 'normal', category: 'other', assigned_to: IDENTITE_DEMO.id,
      created_at: new Date().toISOString(), updated_at: new Date().toISOString(), description: '', user_name: m.display_name,
      messages: [{ id: 'm1', senderName: 'Support Diaspo Niger', isFromSupport: true, content: exiger(a.p_body, 'Message', 10), createdAt: new Date().toISOString() }], resolution_note: null,
    })
    audit('MEMBER_CONTACTED', 'user', m.id, String(a.p_reason))
    return id
  },

  /* support */
  support_ticket_reply: (a) => {
    const t = ligne('support_tickets', a.p_id)
    if (t.status !== 'in_progress') throw new ErreurDemo('55000', 'ticket : le ticket doit être pris en charge pour répondre')
    ;(t.messages as Ligne[]).push({ id: `m${alea()}`, senderName: 'Support Diaspo Niger', isFromSupport: true, content: exiger(a.p_body, 'Réponse'), createdAt: new Date().toISOString() })
    t.updated_at = new Date().toISOString()
    audit('TICKET_REPLIED', 'support_ticket', t.id)
    return 'msg'
  },
  support_ticket_note: (a) => { exiger(a.p_body, 'Note'); audit('TICKET_NOTE_ADDED', 'support_ticket', a.p_id); return alea() },
  support_ticket_transition: (a) => {
    const t = ligne('support_tickets', a.p_id)
    const r = base.tables.support_ticket_transitions.find((x) => x.from_status === t.status && x.to_status === a.p_to)
    if (!r) throw new ErreurDemo('55000', `ticket : passage ${String(t.status)} → ${String(a.p_to)} impossible`)
    if (r.needs_note) exiger(a.p_note, 'Justification')
    Object.assign(t, { status: a.p_to, updated_at: new Date().toISOString(), assigned_to: t.assigned_to ?? IDENTITE_DEMO.id })
    audit('TICKET_' + String(a.p_to).toUpperCase(), 'support_ticket', t.id)
    return a.p_to
  },
  support_ticket_escalate: (a) => { exiger(a.p_reason, 'Motif', 5); audit('TICKET_ESCALATED', 'support_ticket', a.p_id); return null },
  support_ticket_escalation_resolve: (a) => { audit('TICKET_ESCALATION_RESOLVED', 'support_ticket', a.p_id); return null },
  support_sla_status: () => [{ ticket_id: 'demo-t1', first_response_late: true, resolution_late: false }],
  support_template_save: (a) => {
    exiger(a.p_title, 'Titre'); exiger(a.p_body, 'Texte')
    if (a.p_id) Object.assign(ligne('support_reply_templates', a.p_id), { title: a.p_title, body: a.p_body, category: a.p_category })
    else base.tables.support_reply_templates.push({ id: `demo-m${alea()}`, title: a.p_title, body: a.p_body, category: a.p_category })
    audit('TEMPLATE_SAVED', 'support_template', a.p_id ?? null)
    return a.p_id ?? alea()
  },
  support_template_delete: (a) => {
    base.tables.support_reply_templates = base.tables.support_reply_templates.filter((t) => t.id !== a.p_id)
    audit('TEMPLATE_DELETED', 'support_template', a.p_id)
    return null
  },

  /* événements, annuaire, ambassades */
  event_admin_approve: (a) => changer('events', a.p_id, { status: 'upcoming' }, 'EVENT_APPROVED', 'event'),
  event_admin_reject: (a) => { exiger(a.p_reason, 'Motif', 5); return changer('events', a.p_id, { status: 'cancelled' }, 'EVENT_REJECTED', 'event') },
  event_admin_cancel: (a) => { exiger(a.p_reason, 'Motif', 5); return changer('events', a.p_id, { status: 'cancelled' }, 'EVENT_CANCELLED', 'event') },
  business_admin_verify: (a) => { exiger(a.p_source, 'Source'); return changer('businesses', a.p_id, { is_verified: true }, 'BUSINESS_VERIFIED', 'business') },
  business_admin_unverify: (a) => changer('businesses', a.p_id, { is_verified: false }, 'BUSINESS_UNVERIFIED', 'business'),
  business_admin_archive: (a) => changer('businesses', a.p_id, { is_active: false }, 'BUSINESS_ARCHIVED', 'business'),
  business_admin_restore: (a) => changer('businesses', a.p_id, { is_active: true }, 'BUSINESS_RESTORED', 'business'),
  embassy_admin_verify: (a) => { exiger(a.p_source_url, 'Source officielle'); return changer('embassies', a.p_id, { is_verified: true, source_url: a.p_source_url }, 'EMBASSY_VERIFIED', 'embassy') },
  embassy_admin_reject: (a) => changer('embassies', a.p_id, { is_verified: false }, 'EMBASSY_REJECTED', 'embassy'),
  embassy_admin_suspend: (a) => changer('embassies', a.p_id, { is_suspended: true }, 'EMBASSY_SUSPENDED', 'embassy'),
  embassy_admin_unsuspend: (a) => changer('embassies', a.p_id, { is_suspended: false }, 'EMBASSY_UNSUSPENDED', 'embassy'),

  /* campagnes, démarches */
  campaign_save: (a) => {
    const id = `demo-c${alea()}`
    base.tables.campaigns.unshift({ id, type: a.p_type, title: exiger(a.p_title, 'Titre', 3), body: exiger(a.p_body, 'Texte', 10), status: 'draft', review_note: null, created_at: new Date().toISOString(), sent_at: null })
    audit('CAMPAIGN_SAVED', 'campaign', id)
    return id
  },
  campaign_submit: (a) => changer('campaigns', a.p_id, { status: 'pending_approval' }, 'CAMPAIGN_SUBMITTED', 'campaign'),
  campaign_review: (a) => changer('campaigns', a.p_id, { status: a.p_decision === 'approve' ? 'approved' : 'rejected', review_note: a.p_note ?? null }, 'CAMPAIGN_REVIEWED', 'campaign', String(a.p_decision)),
  campaign_cancel: (a) => { exiger(a.p_reason, 'Motif', 5); return changer('campaigns', a.p_id, { status: 'cancelled' }, 'CAMPAIGN_CANCELLED', 'campaign') },
  campaign_send_batch: (a) => { changer('campaigns', a.p_id, { status: 'sent', sent_at: new Date().toISOString() }, 'CAMPAIGN_SENT', 'campaign'); return { processed: 340, created: 340, remaining: 0, status: 'sent' } },
  demarche_draft_save: (a) => {
    const id = `demo-d${alea()}`
    base.tables.demarches_brouillons.unshift({ id, demarche_id: exiger(a.p_demarche_id, 'Identifiant'), status: 'draft', change_reason: a.p_change_reason, review_note: null, submitted_at: null, updated_at: new Date().toISOString() })
    audit('DEMARCHE_DRAFT_SAVED', 'demarche', id)
    return id
  },
  demarche_submit: (a) => changer('demarches_brouillons', a.p_draft_id, { status: 'pending', submitted_at: new Date().toISOString() }, 'DEMARCHE_SUBMITTED', 'demarche'),
  demarche_withdraw: (a) => changer('demarches_brouillons', a.p_draft_id, { status: 'draft' }, 'DEMARCHE_WITHDRAWN', 'demarche'),
  demarche_review: (a) => changer('demarches_brouillons', a.p_draft_id, { status: a.p_decision === 'approve' ? 'approved' : 'rejected', review_note: a.p_note ?? null }, 'DEMARCHE_REVIEWED', 'demarche', String(a.p_decision)),
  demarche_publish: (a) => changer('demarches_brouillons', a.p_draft_id, { status: 'published' }, 'DEMARCHE_PUBLISHED', 'demarche'),

  /* confidentialité, sécurité */
  privacy_request_take: (a) => changer('privacy_requests', a.p_id, { assigned_to: IDENTITE_DEMO.id }, 'PRIVACY_TAKEN', 'privacy_request'),
  privacy_request_verify_identity: (a) => { exiger(a.p_method, 'Méthode', 5); return changer('privacy_requests', a.p_id, { status: 'identity_verified', identity_verified_at: new Date().toISOString() }, 'PRIVACY_IDENTITY_VERIFIED', 'privacy_request') },
  privacy_request_transition: (a) => changer('privacy_requests', a.p_id, { status: a.p_to }, 'PRIVACY_' + String(a.p_to).toUpperCase(), 'privacy_request'),
  security_incident_note: (a) => { exiger(a.p_body, 'Note'); audit('INCIDENT_NOTE', 'security_incident', a.p_id); return alea() },
  security_incident_set_severity: (a) => changer('security_incidents', a.p_id, { severity: a.p_severity }, 'INCIDENT_SEVERITY', 'security_incident'),
  security_incident_transition: (a) => changer('security_incidents', a.p_id, { status: a.p_to, resolved_at: a.p_to === 'resolved' ? new Date().toISOString() : null }, 'INCIDENT_' + String(a.p_to).toUpperCase(), 'security_incident'),

  admin_audit_export: () => ({ rows: base.tables.admin_audit_logs.slice(0, 200), count: Math.min(200, base.tables.admin_audit_logs.length), truncated: false }),
}

async function appelerRpc(nom: string, args: Args = {}) {
  await sleep()
  const f = RPC[nom]
  try {
    if (!f) { audit('(démo) ' + nom, 'demo', null); return { data: null, error: null } }
    return { data: f(args), error: null }
  } catch (e) {
    return { data: null, error: e as ErreurDemo }
  }
}

/* ------------------------------------------------------------- faux client */

export const clientDemo = {
  from: (table: string) => new Requete(table),
  rpc: (nom: string, args?: Args) => appelerRpc(nom, args),
  auth: {
    signOut: () => Promise.resolve({ error: null }),
    setSession: () => Promise.resolve({ error: null }),
  },
}

/** Pour le test : exécute une fonction du faux serveur sans latence. */
export const rpcDemoPourTest = (nom: string, args: Args = {}) => RPC[nom]?.(args)
