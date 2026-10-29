import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { ErrorBox, Loading, Empty, fmtDate } from '../components/States'

interface Tache {
  key: string
  count: number
  urgent: number
  oldest_at: string | null
}

const LIBELLES: Record<string, { label: string; to?: string }> = {
  reports: { label: 'Signalements à traiter', to: '/signalements' },
  support: { label: 'Demandes de support', to: '/support' },
  demarches: { label: 'Démarches à relire', to: '/demarches' },
  campaigns: { label: 'Campagnes à valider', to: '/campagnes' },
  privacy: { label: 'Demandes de données', to: '/confidentialite' },
  incidents: { label: 'Incidents de sécurité', to: '/incidents' },
  listings: { label: 'Fiches annuaire à valider', to: '/annuaire' },
}

export default function Dashboard() {
  const q = useQuery({
    queryKey: ['dashboard-tasks'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('admin_dashboard_tasks')
      if (error) throw error
      return ((data as { items?: Tache[] } | Tache[] | null) ?? []) as unknown
    },
  })

  const items: Tache[] = Array.isArray(q.data)
    ? (q.data as Tache[])
    : ((q.data as { items?: Tache[] } | null)?.items ?? [])

  return (
    <section>
      <h1 className="mb-4 text-xl font-semibold">Vue générale</h1>
      <p className="mb-4 text-sm text-slate-500">
        Éléments en attente selon vos droits. Une erreur de chargement n'est jamais affichée comme zéro.
      </p>
      <button className="btn btn-ghost mb-3" onClick={() => void q.refetch()} disabled={q.isFetching}>
        {q.isFetching ? 'Actualisation…' : 'Actualiser'}
      </button>
      {q.isLoading && <Loading />}
      {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
      {q.isSuccess && items.length === 0 && <Empty>Rien à traiter pour le moment.</Empty>}
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {items.map((t) => {
          const meta = LIBELLES[t.key] ?? { label: t.key }
          const body = (
            <div className="card h-full hover:border-brand">
              <p className="text-sm text-slate-500">{meta.label}</p>
              <p className="mt-1 text-3xl font-semibold">{t.count}</p>
              <p className="mt-1 text-xs text-slate-500">
                {t.urgent > 0 ? `${t.urgent} urgent(s) · ` : ''}plus ancien : {fmtDate(t.oldest_at)}
              </p>
            </div>
          )
          return meta.to ? (
            <Link key={t.key} to={meta.to}>
              {body}
            </Link>
          ) : (
            <div key={t.key}>{body}</div>
          )
        })}
      </div>
    </section>
  )
}
