import { useEffect } from 'react'

const EVENEMENTS = ['pointerdown', 'keydown', 'scroll', 'visibilitychange'] as const

/** Déconnecte après `minutes` sans interaction. Sur une console d'administration, une session oubliée ouverte est un risque. */
export function useInactivite(minutes: number, quandInactif: () => void): void {
  useEffect(() => {
    let t = window.setTimeout(quandInactif, minutes * 60_000)
    const relancer = () => {
      window.clearTimeout(t)
      t = window.setTimeout(quandInactif, minutes * 60_000)
    }
    EVENEMENTS.forEach((e) => window.addEventListener(e, relancer, { passive: true }))
    return () => {
      window.clearTimeout(t)
      EVENEMENTS.forEach((e) => window.removeEventListener(e, relancer))
    }
  }, [minutes, quandInactif])
}
