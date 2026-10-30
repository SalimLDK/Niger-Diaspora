import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { ErrorBox, Loading } from '../components/States'

interface Stats {
  computed_at: string
  users_total: number
  users_active_24h: number
  users_active_7d: number
  users_banned: number
  groups: number
  events_upcoming: number
  businesses_active: number
  reports_open: number
  tickets_open: number
  signups_30d: { day: string; n: number }[]
  top_countries: { country: string; n: number }[]
}

const fmt = (n: number) => n.toLocaleString('fr-FR')

function Kpi({ label, valeur }: { label: string; valeur: number }) {
  return (
    <div className="card">
      <p className="text-sm text-slate-500">{label}</p>
      <p className="mt-1 text-3xl font-semibold">{fmt(valeur)}</p>
    </div>
  )
}

function Inscriptions({ jours }: { jours: Stats['signups_30d'] }) {
  const max = Math.max(1, ...jours.map((j) => j.n))
  const total = jours.reduce((a, j) => a + j.n, 0)
  const w = Math.max(1, jours.length)
  return (
    <div className="card">
      <p className="mb-2 text-sm text-slate-500">Inscriptions sur {w} jours — {fmt(total)} au total</p>
      <svg viewBox={`0 0 ${w * 12} 90`} className="h-32 w-full" role="img" aria-label="Inscriptions par jour">
        {jours.map((j, i) => {
          const h = (j.n / max) * 70
          return (
            <rect key={j.day} x={i * 12 + 1} y={80 - h} width={10} height={h} rx={2} fill="#1f4fd8">
              <title>{`${j.day} : ${j.n}`}</title>
            </rect>
          )
        })}
        <line x1="0" y1="80" x2={w * 12} y2="80" stroke="#cbd5e1" />
      </svg>
    </div>
  )
}

function Pays({ top }: { top: Stats['top_countries'] }) {
  const max = Math.max(1, ...top.map((p) => p.n))
  return (
    <div className="card">
      <p className="mb-2 text-sm text-slate-500">Membres par pays (10 premiers, pays d'au moins 3 membres)</p>
      <ul className="space-y-1">
        {top.map((p) => (
          <li key={p.country} className="flex items-center gap-2 text-sm">
            <span className="w-32 truncate">{p.country}</span>
            <span className="h-3 rounded bg-brand" style={{ width: `${(p.n / max) * 60}%` }} />
            <span className="text-slate-600">{p.n}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

/** Tout vient de `admin_stats()` : des agrégats calculés par le serveur pour qui a le droit, jamais une valeur filtrée en silence. */
export default function Stats() {
  const q = useQuery({
    queryKey: ['stats'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('admin_stats')
      if (error) throw error
      return data as Stats
    },
  })
  const s = q.data

  return (
    <section className="space-y-4">
      <h1 className="text-xl font-semibold">Statistiques</h1>
      <p className="text-sm text-slate-500">
        Chiffres agrégés calculés par le serveur. « Actif » = dernière activité dans la période. Aucune donnée personnelle n'est affichée.
      </p>
      {q.isLoading && <Loading />}
      {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
      {s && (
        <>
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <Kpi label="Membres inscrits" valeur={s.users_total} />
            <Kpi label="Actifs sur 24 h" valeur={s.users_active_24h} />
            <Kpi label="Actifs sur 7 jours" valeur={s.users_active_7d} />
            <Kpi label="Comptes suspendus" valeur={s.users_banned} />
            <Kpi label="Groupes" valeur={s.groups} />
            <Kpi label="Événements à venir" valeur={s.events_upcoming} />
            <Kpi label="Fiches d'annuaire actives" valeur={s.businesses_active} />
            <Kpi label="Signalements à traiter" valeur={s.reports_open} />
            <Kpi label="Tickets ouverts" valeur={s.tickets_open} />
          </div>
          <Inscriptions jours={s.signups_30d} />
          <Pays top={s.top_countries} />
        </>
      )}
    </section>
  )
}
