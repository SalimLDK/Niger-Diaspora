import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { ErrorBox, Loading } from '../components/States'

const JOURS = 30
const LIMITE = 5000

interface Filtre { col: string; op: 'eq' | 'gte' | 'in'; val: string | number | string[] }

/** Compte exact côté serveur. Une erreur s'affiche : jamais un « 0 » de remplacement. */
function Kpi({ label, table, filtres = [], note }: { label: string; table: string; filtres?: Filtre[]; note?: string }) {
  const q = useQuery({
    queryKey: ['stats', 'kpi', table, label],
    queryFn: async () => {
      let req = supabase.from(table).select('*', { count: 'exact', head: true })
      for (const f of filtres) {
        req = f.op === 'eq' ? req.eq(f.col, f.val as string) : f.op === 'gte' ? req.gte(f.col, f.val as string) : req.in(f.col, f.val as string[])
      }
      const { count, error } = await req
      if (error) throw error
      return count ?? 0
    },
  })
  return (
    <div className="card">
      <p className="text-sm text-slate-500">{label}</p>
      {q.isLoading && <p className="mt-1 text-sm text-slate-400">…</p>}
      {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
      {q.isSuccess && <p className="mt-1 text-3xl font-semibold">{q.data.toLocaleString('fr-FR')}</p>}
      {note && <p className="mt-1 text-xs text-slate-400">{note}</p>}
    </div>
  )
}

const iso = (joursAvant: number) => new Date(Date.now() - joursAvant * 86_400_000).toISOString()
const cleJour = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

function Inscriptions() {
  const q = useQuery({
    queryKey: ['stats', 'inscriptions'],
    queryFn: async () => {
      const { data, error } = await supabase.from('users').select('created_at').gte('created_at', iso(JOURS)).limit(LIMITE)
      if (error) throw error
      const par = new Map<string, number>()
      for (let i = JOURS - 1; i >= 0; i--) par.set(cleJour(new Date(Date.now() - i * 86_400_000)), 0)
      for (const r of data ?? []) {
        const k = cleJour(new Date((r as { created_at: string }).created_at))
        if (par.has(k)) par.set(k, (par.get(k) ?? 0) + 1)
      }
      return { jours: [...par.entries()], tronque: (data ?? []).length >= LIMITE }
    },
  })
  if (q.isLoading) return <Loading />
  if (q.isError) return <ErrorBox error={q.error} onRetry={() => void q.refetch()} />
  const jours = q.data!.jours
  const max = Math.max(1, ...jours.map(([, n]) => n))
  const total = jours.reduce((a, [, n]) => a + n, 0)
  return (
    <div className="card">
      <p className="mb-2 text-sm text-slate-500">Inscriptions sur {JOURS} jours — {total} au total{q.data!.tronque ? ' (échantillon tronqué)' : ''}</p>
      <svg viewBox={`0 0 ${JOURS * 12} 90`} className="h-32 w-full" role="img" aria-label="Inscriptions par jour">
        {jours.map(([j, n], i) => {
          const h = (n / max) * 70
          return (
            <g key={j}>
              <rect x={i * 12 + 1} y={80 - h} width={10} height={h} rx={2} fill="#1f4fd8">
                <title>{`${j} : ${n}`}</title>
              </rect>
            </g>
          )
        })}
        <line x1="0" y1="80" x2={JOURS * 12} y2="80" stroke="#cbd5e1" />
        <text x="0" y="90" fontSize="7" fill="#64748b">{jours[0][0]}</text>
        <text x={JOURS * 12} y="90" fontSize="7" fill="#64748b" textAnchor="end">{jours[jours.length - 1][0]}</text>
      </svg>
    </div>
  )
}

function Pays() {
  const q = useQuery({
    queryKey: ['stats', 'pays'],
    queryFn: async () => {
      const { data, error } = await supabase.from('users').select('country_code').not('country_code', 'is', null).limit(LIMITE)
      if (error) throw error
      const m = new Map<string, number>()
      for (const r of data ?? []) {
        const c = (r as { country_code: string }).country_code
        m.set(c, (m.get(c) ?? 0) + 1)
      }
      return { top: [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10), tronque: (data ?? []).length >= LIMITE }
    },
  })
  if (q.isLoading) return <Loading />
  if (q.isError) return <ErrorBox error={q.error} onRetry={() => void q.refetch()} />
  const top = q.data!.top
  const max = Math.max(1, ...top.map(([, n]) => n))
  return (
    <div className="card">
      <p className="mb-2 text-sm text-slate-500">Membres par pays (10 premiers, données agrégées){q.data!.tronque ? ' — échantillon tronqué' : ''}</p>
      <ul className="space-y-1">
        {top.map(([c, n]) => (
          <li key={c} className="flex items-center gap-2 text-sm">
            <span className="w-32 truncate">{c}</span>
            <span className="h-3 rounded bg-brand" style={{ width: `${(n / max) * 60}%` }} />
            <span className="text-slate-600">{n}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

export default function Stats() {
  return (
    <section className="space-y-4">
      <h1 className="text-xl font-semibold">Statistiques</h1>
      <p className="text-sm text-slate-500">
        Chiffres agrégés calculés à la demande. « Actif » = dernière activité dans la période. Aucune donnée personnelle n'est affichée.
      </p>
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Kpi label="Membres inscrits" table="users" />
        <Kpi label="Actifs sur 24 h" table="users" filtres={[{ col: 'last_active_at', op: 'gte', val: iso(1) }]} />
        <Kpi label="Actifs sur 7 jours" table="users" filtres={[{ col: 'last_active_at', op: 'gte', val: iso(7) }]} />
        <Kpi label="Comptes suspendus" table="users" filtres={[{ col: 'is_banned', op: 'eq', val: 'true' }]} />
        <Kpi label="Groupes" table="groups" />
        <Kpi label="Événements à venir" table="events" filtres={[{ col: 'status', op: 'eq', val: 'upcoming' }]} />
        <Kpi label="Fiches d'annuaire actives" table="businesses" filtres={[{ col: 'is_active', op: 'eq', val: 'true' }]} />
        <Kpi label="Signalements à traiter" table="reports" filtres={[{ col: 'status', op: 'in', val: ['pending', 'reviewing', 'escalated'] }]} />
        <Kpi label="Tickets ouverts" table="support_tickets" filtres={[{ col: 'status', op: 'in', val: ['open', 'in_progress'] }]} />
      </div>
      <Inscriptions />
      <Pays />
    </section>
  )
}
