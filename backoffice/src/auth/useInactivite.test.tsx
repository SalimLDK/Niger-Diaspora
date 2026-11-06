// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, renderHook } from '@testing-library/react'
import { useInactivite } from './useInactivite'

beforeEach(() => vi.useFakeTimers())
afterEach(() => { cleanup(); vi.useRealTimers() })

describe('useInactivite', () => {
  it('déconnecte après le délai sans interaction', () => {
    const quand = vi.fn()
    renderHook(() => useInactivite(15, quand))
    vi.advanceTimersByTime(15 * 60_000 - 1)
    expect(quand).not.toHaveBeenCalled()
    vi.advanceTimersByTime(2)
    expect(quand).toHaveBeenCalledTimes(1)
  })

  it('ne relance pas le délai quand le composant se redessine avec un rappel neuf', () => {
    const quand = vi.fn()
    // Un rappel neuf à chaque rendu, comme dans l'application ; un rendu par minute (bandeau d'alertes).
    const { rerender } = renderHook(() => useInactivite(15, () => quand()))
    for (let i = 0; i < 14; i++) {
      vi.advanceTimersByTime(60_000)
      rerender()
    }
    vi.advanceTimersByTime(61_000)
    expect(quand).toHaveBeenCalledTimes(1)
  })

  it('une interaction repousse le délai', () => {
    const quand = vi.fn()
    renderHook(() => useInactivite(15, quand))
    vi.advanceTimersByTime(14 * 60_000)
    window.dispatchEvent(new Event('keydown'))
    vi.advanceTimersByTime(14 * 60_000)
    expect(quand).not.toHaveBeenCalled()
    vi.advanceTimersByTime(2 * 60_000)
    expect(quand).toHaveBeenCalledTimes(1)
  })
})
