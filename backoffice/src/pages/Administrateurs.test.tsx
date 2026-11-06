// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const faux = vi.hoisted(() => ({
  appels: [] as { nom: string; args: Record<string, unknown> }[],
  appelles: [] as { uid: string; adminRole: string }[],
  refus: null as { code: string; message: string } | null,
}))

const compte = { id: 'u-nouveau', display_name: 'Aminata', email: 'a@x.test', admin_role: null, is_admin: false, created_at: '2026-10-01T10:00:00Z' }
const admin = { id: 'u-admin', display_name: 'Salim', email: 's@x.test', admin_role: 'superAdmin', is_admin: true, created_at: '2026-01-01T10:00:00Z' }

vi.mock('../lib/supabase', () => ({
  supabase: {
    rpc: (nom: string, args: Record<string, unknown>) => {
      faux.appels.push({ nom, args })
      const data = args.p_filtre === 'admins' ? [admin] : [compte]
      return Promise.resolve({ data, error: null })
    },
  },
}))
vi.mock('../lib/roles', async (importOriginal) => {
  const reel = await importOriginal<typeof import('../lib/roles')>()
  return {
    ...reel,
    definirRole: (uid: string, adminRole: string) => {
      faux.appelles.push({ uid, adminRole })
      return faux.refus ? Promise.reject(faux.refus) : Promise.resolve()
    },
  }
})

import Administrateurs from './Administrateurs'

const monter = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <Administrateurs />
    </QueryClientProvider>,
  )

beforeEach(() => vi.stubGlobal('confirm', () => true))
afterEach(() => { cleanup(); faux.appels.length = 0; faux.appelles.length = 0; faux.refus = null; vi.unstubAllGlobals() })

describe('page Administrateurs', () => {
  it('liste les administrateurs par la fonction serveur, filtre « admins »', async () => {
    monter()
    expect(await screen.findByText('Salim')).toBeTruthy()
    expect(faux.appels.some((a) => a.nom === 'profils_admin_page' && a.args.p_filtre === 'admins')).toBe(true)
  })

  it('cherche un compte puis lui donne un rôle par la callable', async () => {
    monter()
    fireEvent.change(screen.getByLabelText('Rechercher un compte'), { target: { value: 'amina' } })
    fireEvent.click(screen.getByText('Rechercher'))
    expect(await screen.findByText('Aminata')).toBeTruthy()
    fireEvent.change(screen.getByLabelText('Rôle à donner'), { target: { value: 'contentMod' } })
    fireEvent.click(screen.getByText('Donner ce rôle'))
    await waitFor(() => expect(faux.appelles).toEqual([{ uid: 'u-nouveau', adminRole: 'contentMod' }]))
  })

  it('ne propose le bouton qu\'une fois un rôle choisi', async () => {
    monter()
    fireEvent.change(screen.getByLabelText('Rechercher un compte'), { target: { value: 'amina' } })
    fireEvent.click(screen.getByText('Rechercher'))
    const bouton = (await screen.findByText('Donner ce rôle')) as HTMLButtonElement
    expect(bouton.disabled).toBe(true)
  })

  it('retire les droits avec « none »', async () => {
    monter()
    fireEvent.click(await screen.findByText('Retirer'))
    await waitFor(() => expect(faux.appelles).toEqual([{ uid: 'u-admin', adminRole: 'none' }]))
  })

  it('affiche le refus du serveur, sans le présenter comme un succès', async () => {
    faux.refus = { code: 'functions/permission-denied', message: 'Modification de ses propres droits admin interdite' }
    monter()
    fireEvent.click(await screen.findByText('Retirer'))
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/propres droits/))
    expect(screen.queryByRole('status')).toBeNull()
  })

  it('ne confirme rien si l\'utilisateur annule', async () => {
    vi.stubGlobal('confirm', () => false)
    monter()
    fireEvent.click(await screen.findByText('Retirer'))
    await new Promise((r) => setTimeout(r, 30))
    expect(faux.appelles).toEqual([])
  })
})
