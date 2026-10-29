// @vitest-environment jsdom
import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { Denied, Empty, ErrorBox, fmtDate } from './States'

afterEach(cleanup)

describe('États d\'écran', () => {
  it('un refus de droit s\'affiche comme un refus, jamais comme « 0 »', () => {
    render(<ErrorBox error={{ code: '42501' }} />)
    expect(screen.getByRole('alert').textContent).toMatch(/Accès refusé/)
  })
  it('propose de réessayer quand on le permet', () => {
    render(<ErrorBox error={{ message: 'boom' }} onRetry={() => {}} />)
    expect(screen.getByText('Réessayer')).toBeTruthy()
  })
  it('affiche l\'accès refusé de page', () => {
    render(<Denied />)
    expect(screen.getByRole('alert').textContent).toMatch(/permission/)
  })
  it('affiche l\'état vide', () => {
    render(<Empty>Aucune entrée.</Empty>)
    expect(screen.getByText('Aucune entrée.')).toBeTruthy()
  })
  it('met en forme une date absente par un tiret', () => {
    expect(fmtDate(null)).toBe('—')
  })
})
