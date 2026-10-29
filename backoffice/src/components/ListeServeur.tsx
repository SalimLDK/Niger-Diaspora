import { useState, type ReactNode } from 'react'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useSearchParams } from 'react-router-dom'
import { motifRecherche } from '../lib/search'
import { supabase } from '../lib/supabase'
import { telechargerCsv, versCsv } from '../lib/csv'
import { Empty, ErrorBox, Loading } from './States'

export interface Colonne<T> {
  titre: string
  cell: (r: T) => ReactNode
  /** Colonne SQL pour trier en cliquant sur l'en-tête. */
  tri?: string
}

interface Props<T> {
  titre: string
  aide?: string
  table: string
  select: string
  tri: string
  ascendant?: boolean
  colonnes: Colonne<T>[]
  /** Filtre par statut (valeur de la colonne `status`). */
  statuts?: { valeur: string; libelle: string }[]
  colonneStatut?: string
  taillePage?: number
  rowKey: (r: T) => string
  onSelect?: (r: T) => void
  selectedKey?: string
  /** Colonne texte filtrée par la zone de recherche (ilike). */
  rechercheCol?: string
}

/** Liste paginée côté serveur, en lecture seule. Les droits sont ceux de la RLS : un refus s'affiche. */
export default function ListeServeur<T>({
  titre, aide, table, select, tri, ascendant = false, colonnes, statuts, colonneStatut = 'status',
  taillePage = 25, rowKey, onSelect, selectedKey, rechercheCol,
}: Props<T>) {
  const [statut, setStatut] = useState('')
  const [page, setPage] = useState(0)
  const [params] = useSearchParams()
  const [saisie, setSaisie] = useState(params.get('q') ?? '')
  const [recherche, setRecherche] = useState(params.get('q') ?? '')
  const [triCol, setTriCol] = useState(tri)
  const [asc, setAsc] = useState(ascendant)

  const q = useQuery({
    queryKey: ['liste', table, statut, page, recherche, triCol, asc],
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let req = supabase
        .from(table)
        .select(select, { count: 'exact' })
        .order(triCol, { ascending: asc })
        .range(page * taillePage, page * taillePage + taillePage - 1)
      if (statut) req = req.eq(colonneStatut, statut)
      const m = motifRecherche(recherche)
      if (rechercheCol && m) req = req.ilike(rechercheCol, `%${m}%`)
      const { data, error, count } = await req
      if (error) throw error
      return { rows: (data ?? []) as unknown as T[], total: count ?? 0 }
    },
  })
  const total = q.data?.total ?? 0
  const pages = Math.max(1, Math.ceil(total / taillePage))

  return (
    <section>
      <h1 className="mb-1 text-xl font-semibold">{titre}</h1>
      {aide && <p className="mb-4 text-sm text-slate-500">{aide}</p>}
      {rechercheCol && (
        <form className="mb-3 flex gap-2" onSubmit={(e) => { e.preventDefault(); setPage(0); setRecherche(saisie) }}>
          <input className="input max-w-xs" aria-label="Rechercher" placeholder="Rechercher…" value={saisie} onChange={(e) => setSaisie(e.target.value)} />
          <button className="btn btn-ghost">Rechercher</button>
        </form>
      )}
      {statuts && (
        <select
          className="input mb-4 max-w-[14rem]"
          aria-label="Filtrer par statut"
          value={statut}
          onChange={(e) => { setPage(0); setStatut(e.target.value) }}
        >
          <option value="">Tous les statuts</option>
          {statuts.map((s) => <option key={s.valeur} value={s.valeur}>{s.libelle}</option>)}
        </select>
      )}
      {q.isSuccess && q.data.rows.length > 0 && (
        <button className="btn btn-ghost mb-3" onClick={() => {
          const cols = select.split(',')
          telechargerCsv(`${table}-page${page + 1}.csv`, versCsv(cols, q.data.rows as unknown as Record<string, unknown>[]))
        }}>Exporter cette page (CSV)</button>
      )}
      {q.isLoading && <Loading />}
      {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
      {q.isSuccess && q.data.rows.length === 0 && <Empty>Aucune entrée.</Empty>}
      {q.isSuccess && q.data.rows.length > 0 && (
        <div className="card overflow-x-auto p-0">
          <table className="w-full">
            <thead className="border-b border-slate-200 bg-slate-50">
              <tr>{colonnes.map((c) => (
                <th key={c.titre} className="th" aria-sort={c.tri && c.tri === triCol ? (asc ? 'ascending' : 'descending') : undefined}>
                  {c.tri ? (
                    <button className="font-semibold uppercase" onClick={() => { if (triCol === c.tri) setAsc(!asc); else { setTriCol(c.tri!); setAsc(true) } setPage(0) }}>
                      {c.titre}{c.tri === triCol ? (asc ? ' ▲' : ' ▼') : ''}
                    </button>
                  ) : c.titre}
                </th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {q.data.rows.map((r) => (
                <tr
                  key={rowKey(r)}
                  onClick={onSelect ? () => onSelect(r) : undefined}
                  onKeyDown={onSelect ? (e) => { if (e.key === 'Enter') onSelect(r) } : undefined}
                  tabIndex={onSelect ? 0 : undefined}
                  className={onSelect ? `cursor-pointer hover:bg-blue-50 ${selectedKey === rowKey(r) ? 'bg-blue-50' : ''}` : ''}
                >
                  {colonnes.map((c) => <td key={c.titre} className="td">{c.cell(r)}</td>)}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <div className="mt-3 flex items-center justify-between text-sm text-slate-600">
        <span>{total} entrée(s) · page {page + 1} / {pages}</span>
        <span className="space-x-2">
          <button className="btn btn-ghost" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>Précédent</button>
          <button className="btn btn-ghost" disabled={page + 1 >= pages} onClick={() => setPage((p) => p + 1)}>Suivant</button>
        </span>
      </div>
    </section>
  )
}
