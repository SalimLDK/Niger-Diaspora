import { describe, expect, it } from 'vitest'
import { versCsv } from './csv'

describe('versCsv', () => {
  it('échappe les guillemets et neutralise les formules', () => {
    const out = versCsv(['a', 'b'], [{ a: 'dit "oui"', b: '=HYPERLINK("x")' }])
    expect(out).toBe('"a","b"\r\n"dit ""oui""","\'=HYPERLINK(""x"")"')
  })
  it('rend les valeurs absentes vides et sérialise les objets', () => {
    expect(versCsv(['a', 'b'], [{ b: { k: 1 } }])).toBe('"a","b"\r\n"","{""k"":1}"')
  })
})
