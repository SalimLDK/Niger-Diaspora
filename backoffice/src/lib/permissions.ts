/** Permissions de navigation. Le serveur reste seul juge : ceci ne sert qu'à l'affichage. */
export const PERM = {
  dashboard: 'dashboard.analytics.view',
  members: 'community.members.view',
  reports: 'moderation.reports.view',
  audit: 'security.audit.view',
  groups: 'community.groups.manage',
  campaigns: 'communications.view',
  demarches: 'consular.procedures.approve',
  auditExport: 'security.audit.export',
  stats: 'dashboard.analytics.view',
  roles: 'security.roles.manage',
  embassies: 'consular.embassies.verify',
  settings: 'settings.general.view',
  templates: 'support.templates.manage',
  support: 'support.tickets.view',
  events: 'events.attendance.view',
  directory: 'directory.listings.view',
  privacy: 'privacy.requests.manage',
  incidents: 'security.incidents.manage',
} as const
export type PermKey = (typeof PERM)[keyof typeof PERM]
export const ALL_PERMS: PermKey[] = Object.values(PERM)
