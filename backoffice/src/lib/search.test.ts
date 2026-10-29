import { describe, expect, it } from 'vitest'
import { motifRecherche } from './search'

describe('motifRecherche', () => {
  it('retire les jokers et séparateurs injectables', () => {
    expect(motifRecherche('a%b_c,d)')).toBe('a b c d')
  })
  it('borne la longueur', () => {
    expect(motifRecherche('x'.repeat(200))).toHaveLength(60)
  })
})
