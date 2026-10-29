import { describe, expect, it } from 'vitest'
import { messageErreur } from './erreurs'

describe('messageErreur', () => {
  it('traduit un refus de droit', () => {
    expect(messageErreur({ code: '42501' })).toMatch(/Accès refusé/)
  })
  it('garde le message serveur pour une transition impossible', () => {
    expect(messageErreur({ code: '55000', message: 'passage impossible' })).toBe('passage impossible')
  })
  it('invite à se reconnecter quand le jeton a expiré', () => {
    expect(messageErreur({ code: 'PGRST301' })).toMatch(/reconnectez/)
  })
  it('a un repli pour une erreur inconnue', () => {
    expect(messageErreur(null)).toBe('Erreur inattendue.')
  })
})
