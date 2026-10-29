/** Neutralise les jokers LIKE et les séparateurs du filtre PostgREST. */
export const motifRecherche = (s: string) => s.replace(/[%_\,()]/g, ' ').trim().slice(0, 60)
