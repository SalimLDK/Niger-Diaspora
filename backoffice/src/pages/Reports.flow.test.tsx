// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

/** Faux serveur : tables en mémoire, fonctions serveur enregistrées. */
const faux = vi.hoisted(() => ({
  rpcs: [] as { nom: string; args: Record<string, unknown> }[],
  rpcErreur: null as { code: string; message: string } | null,
  tables: {} as Record<string, unknown[]>,
}))

vi.mock('../lib/supabase', () => {
  const requete = (table: string) => {
    const chain: Record<string, unknown> = {}
    for (const m of ['select', 'order', 'limit', 'eq', 'range', 'in', 'single']) chain[m] = () => chain
    chain.then = (ok: (v: unknown) => unknown) => Promise.resolve({ data: faux.tables[table] ?? [], error: null }).then(ok)
    return chain
  }
  return {
    supabase: {
      from: (t: string) => requete(t),
      rpc: (nom: string, args: Record<string, unknown>) => {
        if (nom === 'admin_has_permission') return Promise.resolve({ data: true, error: null })
        faux.rpcs.push({ nom, args })
        return Promise.resolve({ data: null, error: faux.rpcErreur })
      },
    },
    messageErreur: (e: { message?: string }) => e?.message ?? 'erreur',
  }
})

import Reports from './Reports'

const monter = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <MemoryRouter><Reports /></MemoryRouter>
    </QueryClientProvider>,
  )

afterEach(() => { cleanup(); faux.rpcs.length = 0; faux.rpcErreur = null })

function preparer() {
  faux.tables = {
    reports: [{ id: 'r1', target_type: 'post', target_id: 'p1', reason: 'spam', description: null, status: 'pending', assigned_to: null, reason_code: null, admin_note: null, created_at: '2026-10-01T10:00:00Z' }],
    moderation_report_transitions: [{ from_status: 'pending', to_status: 'dismissed', permission: 'moderation.reports.review', needs_reason: true, needs_note: true, needs_action: false }],
  }
}

describe('parcours de modération (faux serveur)', () => {
  it('une décision envoie le motif normalisé et la justification à la fonction serveur', async () => {
    preparer()
    monter()
    fireEvent.click(await screen.findByText(/post · spam/))
    fireEvent.change(await screen.findByLabelText(/Action/), { target: { value: 'dismissed' } })
    fireEvent.change(await screen.findByLabelText(/Motif/), { target: { value: 'duplicate' } })
    fireEvent.change(screen.getByLabelText(/Justification/), { target: { value: 'Doublon du dossier 12' } })
    fireEvent.click(screen.getByText('Valider'))
    await waitFor(() => expect(faux.rpcs.some((r) => r.nom === 'signalement_transition')).toBe(true))
    expect(faux.rpcs.find((r) => r.nom === 'signalement_transition')?.args).toMatchObject({
      p_report_id: 'r1', p_to: 'dismissed', p_reason_code: 'duplicate', p_note: 'Doublon du dossier 12',
    })
  })

  it('un refus du serveur s\'affiche et ne passe pas pour un succès', async () => {
    preparer()
    faux.rpcErreur = { code: '42501', message: 'Accès refusé : permission requise' }
    monter()
    fireEvent.click(await screen.findByText(/post · spam/))
    fireEvent.change(await screen.findByLabelText(/Action/), { target: { value: 'dismissed' } })
    fireEvent.change(await screen.findByLabelText(/Motif/), { target: { value: 'duplicate' } })
    fireEvent.change(screen.getByLabelText(/Justification/), { target: { value: 'x' } })
    fireEvent.click(screen.getByText('Valider'))
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/Accès refusé/))
  })
})
