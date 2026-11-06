// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'

const faux = vi.hoisted(() => ({
  accepter: vi.fn(() => Promise.resolve()),
  refuser: vi.fn(() => Promise.resolve()),
  deconnexion: vi.fn(() => Promise.resolve()),
}))

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    etat: {
      k: 'invitations',
      email: 'a@x.test',
      items: [{ id: 'inv-1', role: 'auditor', invited_by_name: 'Salim', expires_at: '2026-12-01T10:00:00Z' }],
    },
    connexion: vi.fn(), validerCode: vi.fn(), confirmerEnrolement: vi.fn(),
    accepter: faux.accepter, refuser: faux.refuser, deconnexion: faux.deconnexion,
  }),
}))
vi.mock('qrcode', () => ({ default: { toDataURL: () => Promise.resolve('') } }))
vi.mock('firebase/auth', () => ({ sendPasswordResetEmail: vi.fn() }))
vi.mock('../lib/firebase', () => ({ fbAuth: {} }))

import Login from './Login'

afterEach(() => { cleanup(); vi.clearAllMocks() })

describe('écran d\'invitation', () => {
  it('présente le rôle et l\'invitant, et ne donne aucun droit sans clic', () => {
    render(<Login />)
    expect(screen.getByText('Auditeur')).toBeTruthy()
    expect(screen.getByText(/Invitation de Salim/)).toBeTruthy()
    expect(faux.accepter).not.toHaveBeenCalled()
  })

  it('accepter envoie l\'identifiant de l\'invitation, pas un rôle', async () => {
    render(<Login />)
    fireEvent.click(screen.getByText('Accepter'))
    await waitFor(() => expect(faux.accepter).toHaveBeenCalledWith('inv-1'))
  })

  it('refuser appelle le refus avec l\'identifiant', async () => {
    render(<Login />)
    fireEvent.click(screen.getByText('Refuser'))
    await waitFor(() => expect(faux.refuser).toHaveBeenCalledWith('inv-1'))
  })

  it('affiche l\'erreur du serveur au lieu d\'annoncer une activation', async () => {
    faux.accepter.mockImplementationOnce(() => Promise.reject(new Error('Reconnectez-vous pour confirmer')))
    render(<Login />)
    fireEvent.click(screen.getByText('Accepter'))
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/Reconnectez-vous/))
  })

  it('« Répondre plus tard » déconnecte sans rien décider', () => {
    render(<Login />)
    fireEvent.click(screen.getByText('Répondre plus tard'))
    expect(faux.deconnexion).toHaveBeenCalled()
    expect(faux.accepter).not.toHaveBeenCalled()
    expect(faux.refuser).not.toHaveBeenCalled()
  })
})
