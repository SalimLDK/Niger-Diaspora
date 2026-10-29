import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search } from 'lucide-react'
import { messageErreur, supabase } from '../lib/supabase'

interface Hit { id: string; title: string | null; subtitle?: string | null; status?: string | null }
interface Groupe { kind: string; items: Hit[] }

const CIBLES: Record<string, { label: string; to: string }> = {
  members: { label: 'Membres', to: '/membres' },
  tickets: { label: 'Support', to: '/support' },
  reports: { label: 'Signalements', to: '/signalements' },
  events: { label: 'Événements', to: '/evenements' },
  businesses: { label: 'Annuaire', to: '/annuaire' },
  groups: { label: 'Groupes', to: '/groupes' },
}

/** Recherche transversale : le serveur ne renvoie que les groupes que votre rôle peut voir. */
export default function RechercheGlobale() {
  const [q, setQ] = useState('')
  const [res, setRes] = useState<Groupe[] | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const nav = useNavigate()

  async function chercher(e: FormEvent) {
    e.preventDefault()
    setErr(null)
    if (q.trim().length < 2) return setErr('Saisissez au moins 2 caractères.')
    const { data, error } = await supabase.rpc('admin_global_search', { p_query: q.trim(), p_limit: 6 })
    if (error) { setRes(null); return setErr(messageErreur(error)) }
    setRes(((data as { groups?: Groupe[] } | null)?.groups ?? []))
  }

  return (
    <div className="relative">
      <form onSubmit={(e) => void chercher(e)} className="flex items-center gap-2" role="search">
        <Search size={16} className="text-slate-400" />
        <input className="input w-56" aria-label="Recherche globale" placeholder="Rechercher partout…" value={q}
          onChange={(e) => { setQ(e.target.value); if (!e.target.value) setRes(null) }} />
      </form>
      {(res || err) && (
        <div className="absolute right-0 z-10 mt-2 w-80 max-w-[90vw] rounded-lg border border-slate-200 bg-white p-3 text-sm shadow-lg">
          {err && <p role="alert" className="text-red-600">{err}</p>}
          {res && res.length === 0 && <p className="text-slate-500">Aucun résultat.</p>}
          {res?.map((g) => (
            <div key={g.kind} className="mb-2">
              <p className="text-xs font-semibold uppercase text-slate-500">{CIBLES[g.kind]?.label ?? g.kind}</p>
              <ul>
                {g.items.map((h) => (
                  <li key={h.id}>
                    <button className="w-full rounded px-2 py-1 text-left hover:bg-blue-50"
                      onClick={() => { const c = CIBLES[g.kind]; if (c) nav(`${c.to}?q=${encodeURIComponent(h.title ?? '')}`); setRes(null) }}>
                      {h.title ?? h.id}
                      {h.subtitle && <span className="text-slate-500"> · {h.subtitle}</span>}
                      {h.status && <span className="text-slate-400"> · {h.status}</span>}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ))}
          <button className="btn btn-ghost mt-1 w-full justify-center" onClick={() => setRes(null)}>Fermer</button>
        </div>
      )}
    </div>
  )
}
