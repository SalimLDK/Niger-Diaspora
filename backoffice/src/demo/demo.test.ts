// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

// Le vrai client ne doit JAMAIS être touché en démo : on le remplace par un espion qui échoue au moindre appel.
const reel = vi.hoisted(() => ({
  appels: [] as string[],
}))
vi.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    from: () => { reel.appels.push('from'); throw new Error('RÉSEAU : from') },
    rpc: () => { reel.appels.push('rpc'); throw new Error('RÉSEAU : rpc') },
    auth: { signOut: () => { reel.appels.push('signOut'); throw new Error('RÉSEAU : signOut') } },
  }),
}))
vi.mock('../lib/env', () => ({
  env: { supabaseUrl: 'https://x.invalid', supabaseAnonKey: 'k', firebaseApiKey: 'k', firebaseAppId: 'a', firebaseProjectId: 'p', firebaseAuthDomain: 'd' },
}))

import { supabase } from '../lib/supabase'
import { activerDemo, desactiverDemo, demoActif } from './etat'
import { reinitialiserDemo, donneesDemo } from './client'
import { definirRole } from '../lib/roles'
import { ecrireSection, lireReglages } from '../lib/reglages'

beforeEach(() => { reinitialiserDemo(); activerDemo() })
afterEach(() => { desactiverDemo(); reel.appels.length = 0 })

describe('mode démo : isolation', () => {
  it('aucun appel ne part vers le vrai client tant que la démo est active', async () => {
    await supabase.from('users').select('id', { count: 'exact' })
    await supabase.rpc('admin_dashboard_tasks')
    await supabase.auth.signOut()
    expect(reel.appels).toEqual([])
  })

  it('en sortant de la démo, le vrai client reprend IMMÉDIATEMENT la main', () => {
    desactiverDemo()
    expect(demoActif()).toBe(false)
    expect(() => supabase.rpc('admin_dashboard_tasks')).toThrow(/RÉSEAU/)
    expect(reel.appels).toEqual(['rpc'])
  })

  it('les données se recréent à neuf à chaque entrée (rien n\'est conservé)', async () => {
    await supabase.rpc('support_ticket_reply', { p_id: 'demo-t2', p_body: 'Une réponse de test' })
    expect((donneesDemo().tables.support_tickets[1].messages as unknown[]).length).toBe(3)
    reinitialiserDemo()
    expect((donneesDemo().tables.support_tickets[1].messages as unknown[]).length).toBe(2)
  })

  it('les rôles et les réglages restent en mémoire, sans Firebase', async () => {
    await definirRole('demo-u1', 'auditor')
    expect(donneesDemo().tables.users.find((u) => u.id === 'demo-u1')?.admin_role).toBe('auditor')
    await ecrireSection('general', { appName: 'Test', maintenance: true }, 'essai de démo')
    expect((await lireReglages()).general.appName).toBe('Test')
  })
})

describe('mode démo : comportement du faux serveur', () => {
  const lire = async (table: string, f?: (q: ReturnType<typeof supabase.from>) => unknown) =>
    (await (f ? f(supabase.from(table)) : supabase.from(table).select('*', { count: 'exact' })) as PromiseLike<{ data: unknown[]; count: number }>)

  it('pagine, filtre, trie et compte comme la vraie liste', async () => {
    const r = await supabase.from('users').select('id,display_name', { count: 'exact' }).order('display_name', { ascending: true }).range(0, 4)
    expect(r.data).toHaveLength(5)
    expect(r.count).toBeGreaterThan(5)
    const bannis = await supabase.from('users').select('id', { count: 'exact' }).eq('is_banned', 'true')
    expect(bannis.count).toBe(1)
  })

  it('une décision de signalement respecte les transitions et exige motif et justification', async () => {
    const sans = await supabase.rpc('signalement_transition', { p_report_id: 'demo-r3', p_to: 'dismissed' })
    expect(sans.error?.code).toBe('22023')
    const impossible = await supabase.rpc('signalement_transition', { p_report_id: 'demo-r5', p_to: 'dismissed', p_reason_code: 'duplicate', p_note: 'x' })
    expect(impossible.error?.code).toBe('55000')
    const ok = await supabase.rpc('signalement_transition', { p_report_id: 'demo-r3', p_to: 'dismissed', p_reason_code: 'duplicate', p_note: 'Doublon' })
    expect(ok.error).toBeNull()
    expect(donneesDemo().tables.reports.find((r) => r.id === 'demo-r3')?.status).toBe('dismissed')
  })

  it('chaque action est inscrite au journal de démonstration', async () => {
    const avant = donneesDemo().tables.admin_audit_logs.length
    await supabase.rpc('event_admin_approve', { p_id: 'demo-e3' })
    expect(donneesDemo().tables.admin_audit_logs.length).toBe(avant + 1)
    expect(donneesDemo().tables.admin_audit_logs[0].action).toBe('EVENT_APPROVED')
  })

  it('la recherche de membres masque l\'e-mail et refuse moins de 3 caractères', async () => {
    const trop = await supabase.rpc('admin_member_search', { p_term: 'am' })
    expect(trop.error?.code).toBe('22023')
    const r = await supabase.rpc('admin_member_search', { p_term: 'membre' })
    const premier = (r.data as { email_masked: string }[])[0]
    expect(premier.email_masked).toMatch(/^m•••@e•••\.test$/)
  })

  it('un rôle superAdmin attend une approbation, un autre rôle part directement', async () => {
    await supabase.rpc('admin_invitation_create', { p_member_id: 'demo-u1', p_role: 'superAdmin' })
    await supabase.rpc('admin_invitation_create', { p_member_id: 'demo-u2', p_role: 'auditor' })
    const liste = (await supabase.rpc('admin_invitation_list')).data as { invitee_id: string; status: string }[]
    expect(liste.find((i) => i.invitee_id === 'demo-u1')?.status).toBe('pending_approval')
    expect(liste.find((i) => i.invitee_id === 'demo-u2')?.status).toBe('pending')
    const doublon = await supabase.rpc('admin_invitation_create', { p_member_id: 'demo-u2', p_role: 'analyst' })
    expect(doublon.error?.code).toBe('55000')
  })

  it('toutes les permissions sont accordées et une fonction inconnue réussit sans rien casser', async () => {
    expect((await supabase.rpc('admin_has_permission', { perm: 'security.audit.export' })).data).toBe(true)
    expect((await supabase.rpc('fonction_inconnue_de_demo')).error).toBeNull()
  })

  it('le tableau de bord se calcule sur les données vivantes', async () => {
    const t = (await supabase.rpc('admin_dashboard_tasks')).data as { items: { key: string; count: number }[] }
    expect(t.items.find((i) => i.key === 'reports')?.count).toBe(4)
    await lire('reports')
  })
})
