// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const faux = vi.hoisted(() => ({
  appels: [] as { nom: string; args: Record<string, unknown> }[],
  retraits: [] as { uid: string; adminRole: string }[],
  refus: null as { code: string; message: string } | null,
  refusRetrait: null as { code: string; message: string } | null,
  invitations: [] as unknown[],
}))

const admin = { id: 'u-admin', display_name: 'Salim', email: 'salim@exemple.com', admin_role: 'superAdmin', is_admin: true, created_at: '2026-01-01T10:00:00Z' }
const trouve = { id: 'u-nouveau', display_name: 'Aminata', email_masked: 'a•••@e•••.com', created_at: '2026-10-01T10:00:00Z', is_admin: false, admin_role: null }

vi.mock('../lib/supabase', () => ({
  supabase: {
    rpc: (nom: string, args: Record<string, unknown>) => {
      faux.appels.push({ nom, args })
      if (nom === 'profils_admin_page') return Promise.resolve({ data: [admin], error: null })
      if (nom === 'admin_member_search') return Promise.resolve({ data: [trouve], error: null })
      if (nom === 'admin_invitation_list') return Promise.resolve({ data: faux.invitations, error: null })
      return Promise.resolve({ data: null, error: faux.refus })
    },
  },
}))
vi.mock('../lib/roles', async (importOriginal) => {
  const reel = await importOriginal<typeof import('../lib/roles')>()
  return {
    ...reel,
    definirRole: (uid: string, adminRole: string) => {
      faux.retraits.push({ uid, adminRole })
      return faux.refusRetrait ? Promise.reject(faux.refusRetrait) : Promise.resolve()
    },
  }
})

import Administrateurs from './Administrateurs'

const monter = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })}>
      <Administrateurs />
    </QueryClientProvider>,
  )

const appel = (nom: string) => faux.appels.find((a) => a.nom === nom)

async function chercherEtChoisir(role: string) {
  fireEvent.change(screen.getByLabelText('Rechercher un compte'), { target: { value: 'amina' } })
  fireEvent.click(screen.getByText('Rechercher'))
  expect(await screen.findByText('Aminata')).toBeTruthy()
  fireEvent.change(screen.getByLabelText('Rôle à donner'), { target: { value: role } })
}

beforeEach(() => vi.stubGlobal('confirm', () => true))
afterEach(() => {
  cleanup(); faux.appels.length = 0; faux.retraits.length = 0; faux.refus = null; faux.refusRetrait = null; faux.invitations = []
  vi.unstubAllGlobals()
})

describe('page Administrateurs : invitations', () => {
  it('cherche par la fonction serveur et n\'affiche que l\'e-mail masqué', async () => {
    monter()
    fireEvent.change(screen.getByLabelText('Rechercher un compte'), { target: { value: 'amina' } })
    fireEvent.click(screen.getByText('Rechercher'))
    expect(await screen.findByText('a•••@e•••.com')).toBeTruthy()
    expect(appel('admin_member_search')?.args).toEqual({ p_term: 'amina' })
  })

  it('invite au lieu de donner le rôle : aucune attribution directe', async () => {
    monter()
    await chercherEtChoisir('contentMod')
    fireEvent.click(screen.getByText('Inviter'))
    await waitFor(() => expect(appel('admin_invitation_create')?.args).toEqual({ p_member_id: 'u-nouveau', p_role: 'contentMod' }))
    expect(faux.retraits).toEqual([])
    expect(await screen.findByRole('status')).toBeTruthy()
  })

  it('le bouton n\'est actif qu\'une fois un rôle choisi', async () => {
    monter()
    fireEvent.change(screen.getByLabelText('Rechercher un compte'), { target: { value: 'amina' } })
    fireEvent.click(screen.getByText('Rechercher'))
    const bouton = (await screen.findByText('Inviter')) as HTMLButtonElement
    expect(bouton.disabled).toBe(true)
  })

  it('une invitation super-administrateur prévient qu\'un second approbateur est requis', async () => {
    const confirmation = vi.fn(() => true)
    vi.stubGlobal('confirm', confirmation)
    monter()
    await chercherEtChoisir('superAdmin')
    fireEvent.click(screen.getByText('Inviter'))
    await waitFor(() => expect(confirmation).toHaveBeenCalled())
    expect(String((confirmation.mock.calls[0] as unknown[])[0])).toMatch(/second super-administrateur/)
  })

  it('affiche le refus du serveur sans l\'annoncer comme un succès', async () => {
    faux.refus = { code: '55000', message: 'invitation : une invitation est déjà en cours pour cette personne' }
    monter()
    await chercherEtChoisir('auditor')
    fireEvent.click(screen.getByText('Inviter'))
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/déjà en cours/))
    expect(screen.queryByRole('status')).toBeNull()
  })

  it('ne crée rien si l\'administrateur annule la confirmation', async () => {
    vi.stubGlobal('confirm', () => false)
    monter()
    await chercherEtChoisir('auditor')
    fireEvent.click(screen.getByText('Inviter'))
    await new Promise((r) => setTimeout(r, 30))
    expect(appel('admin_invitation_create')).toBeUndefined()
  })
})

describe('page Administrateurs : approbation et révocation', () => {
  const base = { invitee_id: 'u-x', invitee_name: 'Moussa', invitee_email_masked: 'm•••@e•••.com', role: 'superAdmin',
    invited_by_name: 'Salim', approved_by_name: null, expires_at: '2026-12-01T10:00:00Z', created_at: '2026-11-01T10:00:00Z' }

  it('propose d\'approuver une invitation en attente d\'approbation', async () => {
    faux.invitations = [{ ...base, id: 'inv-1', status: 'pending_approval' }]
    monter()
    fireEvent.click(await screen.findByText('Approuver'))
    await waitFor(() => expect(appel('admin_invitation_approve')?.args).toEqual({ p_id: 'inv-1' }))
  })

  it('révoque une invitation ouverte', async () => {
    faux.invitations = [{ ...base, id: 'inv-2', status: 'pending', role: 'auditor' }]
    monter()
    fireEvent.click(await screen.findByText('Révoquer'))
    await waitFor(() => expect(appel('admin_invitation_revoke')?.args).toEqual({ p_id: 'inv-2' }))
  })

  it('ne propose aucune action sur une invitation clôturée', async () => {
    faux.invitations = [{ ...base, id: 'inv-3', status: 'accepted', role: 'auditor' }]
    monter()
    expect(await screen.findByText('Acceptée')).toBeTruthy()
    expect(screen.queryByText('Approuver')).toBeNull()
    expect(screen.queryByText('Révoquer')).toBeNull()
  })
})

describe('page Administrateurs : retrait immédiat', () => {
  it('liste les administrateurs avec e-mail masqué', async () => {
    monter()
    expect(await screen.findByText('Salim')).toBeTruthy()
    expect(screen.getByText('s•••@e•••.com')).toBeTruthy()
    expect(screen.queryByText('salim@exemple.com')).toBeNull()
  })

  it('retire les droits avec « none », sans invitation', async () => {
    monter()
    fireEvent.click(await screen.findByText('Retirer'))
    await waitFor(() => expect(faux.retraits).toEqual([{ uid: 'u-admin', adminRole: 'none' }]))
  })

  it('affiche le refus du retrait', async () => {
    faux.refusRetrait = { code: 'functions/permission-denied', message: 'Modification de ses propres droits admin interdite' }
    monter()
    fireEvent.click(await screen.findByText('Retirer'))
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/propres droits/))
  })
})
