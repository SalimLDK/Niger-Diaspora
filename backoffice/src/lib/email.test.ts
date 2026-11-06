import { describe, expect, it } from 'vitest'
import { masquerEmail } from './email'

describe('masquerEmail', () => {
  it('masque le nom et le domaine, garde l\'initiale et l\'extension', () => {
    expect(masquerEmail('amina.n@exemple.com')).toBe('a•••@e•••.com')
  })
  it('ne montre jamais une adresse mal formée ou absente', () => {
    for (const v of [null, undefined, '', 'sans-arobase', 'a@b', '@x.com']) expect(masquerEmail(v)).toBe('')
  })
})
