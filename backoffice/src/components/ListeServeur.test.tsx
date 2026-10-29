// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const resultat = vi.hoisted(() => ({ value: { data: [] as unknown[], error: null as unknown, count: 0 } }))

vi.mock('../lib/supabase', () => {
  const chain: Record<string, unknown> = {}
  for (const m of ['select', 'order', 'range', 'eq', 'ilike']) chain[m] = () => chain
  chain.then = (ok: (v: unknown) => unknown) => Promise.resolve(resultat.value).then(ok)
  return { supabase: { from: () => chain } }
})

import ListeServeur from './ListeServeur'

const monter = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <MemoryRouter>
        <ListeServeur<{ id: string; nom: string }>
          titre="Test" table="t" select="id,nom" tri="nom" rowKey={(r) => r.id}
          colonnes={[{ titre: 'Nom', cell: (r) => r.nom }]}
        />
      </MemoryRouter>
    </QueryClientProvider>,
  )

afterEach(cleanup)

describe('ListeServeur', () => {
  it('affiche les lignes et le total', async () => {
    resultat.value = { data: [{ id: '1', nom: 'Aminata' }], error: null, count: 1 }
    monter()
    await waitFor(() => expect(screen.getByText('Aminata')).toBeTruthy())
    expect(screen.getByText(/1 entrée\(s\)/)).toBeTruthy()
  })

  it('affiche l\'état vide quand il n\'y a rien', async () => {
    resultat.value = { data: [], error: null, count: 0 }
    monter()
    await waitFor(() => expect(screen.getByText('Aucune entrée.')).toBeTruthy())
  })

  it('affiche un refus de droit au lieu d\'une liste vide', async () => {
    resultat.value = { data: [], error: { code: '42501', message: 'x' }, count: 0 }
    monter()
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/Accès refusé/))
    expect(screen.queryByText('Aucune entrée.')).toBeNull()
  })
})
