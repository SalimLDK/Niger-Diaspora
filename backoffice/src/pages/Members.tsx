import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { motifRecherche } from '../lib/search'
import { PanneauMembre } from '../components/Panneaux'
import { Badge, Empty, ErrorBox, Loading, fmtDate } from '../components/States'

const PAGE = 25

interface Membre {
  id: string
  display_name: string | null
  country_code: string | null
  city: string | null
  created_at: string
  last_active_at: string | null
  is_banned: boolean | null
  is_verified: boolean
  admin_role: string | null
}

export default function Members() {
  const [params] = useSearchParams()
  const [saisie, setSaisie] = useState(params.get('q') ?? '')
  const [recherche, setRecherche] = useState(params.get('q') ?? '')
  const [statut, setStatut] = useState<'tous' | 'actifs' | 'suspendus'>('tous')
  const [page, setPage] = useState(0)
  const [sel, setSel] = useState<Membre | null>(null)

  const q = useQuery({
    queryKey: ['membres', recherche, statut, page],
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let req = supabase
        .from('users')
        .select('id,display_name,country_code,city,created_at,last_active_at,is_banned,is_verified,admin_role', {
          count: 'exact',
        })
        .order('created_at', { ascending: false })
        .range(page * PAGE, page * PAGE + PAGE - 1)
      const m = motifRecherche(recherche)
      if (m) req = req.or(`display_name.ilike.%${m}%,id.eq.${m}`)
      if (statut === 'suspendus') req = req.eq('is_banned', true)
      if (statut === 'actifs') req = req.or('is_banned.is.null,is_banned.eq.false')
      const { data, error, count } = await req
      if (error) throw error
      return { rows: (data ?? []) as Membre[], total: count ?? 0 }
    },
  })

  const total = q.data?.total ?? 0
  const pages = Math.max(1, Math.ceil(total / PAGE))

  return (
    <section className="grid gap-4 lg:grid-cols-[1fr_22rem]">
      <div>
      <h1 className="mb-4 text-xl font-semibold">Membres</h1>
      <form
        className="mb-4 flex flex-wrap gap-2"
        onSubmit={(e) => {
          e.preventDefault()
          setPage(0)
          setRecherche(saisie)
        }}
      >
        <input
          className="input max-w-xs"
          placeholder="Pseudo ou identifiant"
          aria-label="Rechercher un membre"
          value={saisie}
          onChange={(e) => setSaisie(e.target.value)}
        />
        <select
          className="input max-w-[11rem]"
          aria-label="Filtrer par statut"
          value={statut}
          onChange={(e) => {
            setPage(0)
            setStatut(e.target.value as typeof statut)
          }}
        >
          <option value="tous">Tous</option>
          <option value="actifs">Actifs</option>
          <option value="suspendus">Suspendus</option>
        </select>
        <button className="btn btn-primary">Rechercher</button>
      </form>

      {q.isLoading && <Loading />}
      {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
      {q.isSuccess && q.data.rows.length === 0 && <Empty>Aucun membre ne correspond.</Empty>}
      {q.isSuccess && q.data.rows.length > 0 && (
        <div className="card overflow-x-auto p-0">
          <table className="w-full">
            <thead className="border-b border-slate-200 bg-slate-50">
              <tr>
                <th className="th">Pseudo</th>
                <th className="th">Lieu</th>
                <th className="th">Inscrit le</th>
                <th className="th">Dernière activité</th>
                <th className="th">Statut</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {q.data.rows.map((m) => (
                <tr key={m.id} onClick={() => setSel(m)} className="cursor-pointer hover:bg-blue-50">
                  <td className="td font-medium">{m.display_name ?? '—'}</td>
                  <td className="td">{[m.city, m.country_code].filter(Boolean).join(', ') || '—'}</td>
                  <td className="td">{fmtDate(m.created_at)}</td>
                  <td className="td">{fmtDate(m.last_active_at)}</td>
                  <td className="td space-x-1">
                    {m.is_banned ? <Badge tone="red">Suspendu</Badge> : <Badge tone="green">Actif</Badge>}
                    {m.is_verified && <Badge tone="blue">Vérifié</Badge>}
                    {m.admin_role && <Badge tone="amber">Admin</Badge>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <div className="mt-3 flex items-center justify-between text-sm text-slate-600">
        <span>
          {total} membre(s) · page {page + 1} / {pages}
        </span>
        <span className="space-x-2">
          <button className="btn btn-ghost" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
            Précédent
          </button>
          <button className="btn btn-ghost" disabled={page + 1 >= pages} onClick={() => setPage((p) => p + 1)}>
            Suivant
          </button>
        </span>
      </div>
      </div>
      {sel && <PanneauMembre key={sel.id} id={sel.id} nom={sel.display_name ?? 'Membre'} onClose={() => setSel(null)} />}
    </section>
  )
}
