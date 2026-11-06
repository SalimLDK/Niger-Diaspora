import { useEffect, useRef } from 'react'

const EVENEMENTS = ['pointerdown', 'keydown', 'scroll', 'visibilitychange'] as const

/**
 * Déconnecte après `minutes` sans interaction. Sur une console d'administration, une session oubliée ouverte est un risque.
 *
 * Le rappel est gardé dans une référence : l'appelant en passe un neuf à chaque rendu, et le mettre en dépendance
 * de l'effet relançait le minuteur à chaque rendu — or le bandeau d'alertes rafraîchit la page chaque minute, donc
 * le délai de 15 minutes ne s'écoulait jamais.
 */
export function useInactivite(minutes: number, quandInactif: () => void): void {
  const rappel = useRef(quandInactif)
  rappel.current = quandInactif

  useEffect(() => {
    const delai = minutes * 60_000
    let t = window.setTimeout(() => rappel.current(), delai)
    const relancer = () => {
      window.clearTimeout(t)
      t = window.setTimeout(() => rappel.current(), delai)
    }
    EVENEMENTS.forEach((e) => window.addEventListener(e, relancer, { passive: true }))
    return () => {
      window.clearTimeout(t)
      EVENEMENTS.forEach((e) => window.removeEventListener(e, relancer))
    }
  }, [minutes])
}
