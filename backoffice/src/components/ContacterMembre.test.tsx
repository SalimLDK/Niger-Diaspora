// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const faux = vi.hoisted(() => ({ appels: [] as { nom: string; args: Record<string, unknown> }[], erreur: null as { code: string; message: string } | null }))

vi.mock('../lib/supabase', () => ({
  supabase: {
    rpc: (nom: string, args: Record<string, unknown>) => {
      faux.appels.push({ nom, args })
      return Promise.resolve({ data: faux.erreur ? null : 'ticket-1', error: faux.erreur })
    },
  },
}))

import ContacterMembre from './ContacterMembre'

const monter = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { mutations: { retry: false } } })}>
      <ContacterMembre membreId="m1" nom="Aminata" />
    </QueryClientProvider>,
  )

function remplir() {
  fireEvent.change(screen.getByLabelText('Motif du contact'), { target: { value: 'profile_update' } })
  fireEvent.change(screen.getByPlaceholderText('Sujet'), { target: { value: 'Votre profil' } })
  fireEvent.change(screen.getByPlaceholderText('Message'), { target: { value: 'Merci de vérifier votre ville.' } })
  fireEvent.click(screen.getByText('Envoyer'))
}

afterEach(() => { cleanup(); faux.appels.length = 0; faux.erreur = null; vi.restoreAllMocks() })

describe('Contacter un membre', () => {
  it('envoie motif, sujet et message à la fonction serveur, après confirmation', async () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true)
    monter()
    remplir()
    await waitFor(() => expect(faux.appels).toHaveLength(1))
    expect(faux.appels[0]).toEqual({
      nom: 'member_admin_contact',
      args: { p_member_id: 'm1', p_reason: 'profile_update', p_subject: 'Votre profil', p_body: 'Merci de vérifier votre ville.' },
    })
    await waitFor(() => expect(screen.getByRole('status').textContent).toMatch(/ticket/))
  })

  it("n'envoie rien si l'administrateur refuse la confirmation", () => {
    vi.spyOn(window, 'confirm').mockReturnValue(false)
    monter()
    remplir()
    expect(faux.appels).toHaveLength(0)
  })

  it('affiche le refus du serveur (limite de contacts) au lieu d\'un succès', async () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true)
    faux.erreur = { code: '55000', message: 'contact : ce membre a déjà reçu 3 messages en 24 h' }
    monter()
    remplir()
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/3 messages/))
    expect(screen.queryByRole('status')).toBeNull()
  })
})
