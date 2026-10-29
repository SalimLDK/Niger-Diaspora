import { describe, expect, it, vi } from 'vitest'

vi.mock('firebase/firestore', () => ({}))
vi.mock('firebase/app', () => ({ getApp: () => ({}) }))
vi.mock('./firebase', () => ({ fbAuth: { currentUser: null } }))

import { analyserSection, ecrireSection } from './reglages'

describe('analyserSection', () => {
  it('accepte un objet', () => {
    expect(analyserSection('{"a":1}')).toEqual({ ok: true, valeur: { a: 1 } })
  })
  it('refuse un tableau, un scalaire et du texte invalide', () => {
    expect(analyserSection('[1]').ok).toBe(false)
    expect(analyserSection('3').ok).toBe(false)
    expect(analyserSection('{a').ok).toBe(false)
  })
})

describe('ecrireSection', () => {
  it('refuse sans session', async () => {
    await expect(ecrireSection('x', {}, 'motif')).rejects.toThrow(/session/)
  })
})
