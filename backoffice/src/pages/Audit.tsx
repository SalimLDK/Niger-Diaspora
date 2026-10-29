import { useState } from 'react'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { messageErreur, supabase } from '../lib/supabase'
import { useAuth } from '../auth/AuthProvider'
import { PERM } from '../lib/permissions'
import { telechargerCsv, versCsv } from '../lib/csv'
import { Badge, Empty, ErrorBox, Loading, fmtDate } from '../components/States'

const PAGE = 30

interface Ligne {
  id: string
  admin_id: string
  admin_name: string | null
  action: string
  target_type: string | null
  target_id: string | null
  result: string | null
  reason_code: string | null
  created_at: string
}

interface Filtre { acteur: string; action: string; resultat: string; du: string; au: string }
const VIDE: Filtre = { acteur: '', action: '', resultat: '', du: '', au: '' }

export default function Audit() {
  const { peut } = useAuth()
  const [saisie, setSaisie] = useState<Filtre>(VIDE)
  const [filtre, setFiltre] = useState<Filtre>(VIDE)
  const [page, setPage] = useState(0)
  const [exportMsg, setExportMsg] = useState<string | null>(null)

  const q = useQuery({
    queryKey: ['audit', filtre, page],
    placeholderData: keepPreviousData,
    queryFn: async () => {
      let req = supabase
        .from('admin_audit_logs')
        .select('id,admin_id,admin_name,action,target_type,target_id,result,reason_code,created_at', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(page * PAGE, page * PAGE + PAGE - 1)
      if (filtre.action) req = req.eq('action', filtre.action)
      if (filtre.resultat) req = req.eq('result', filtre.resultat)
      if (filtre.acteur) req = req.eq('admin_id', filtre.acteur)
      if (filtre.du) req = req.gte('created_at', new Date(filtre.du).toISOString())
      if (filtre.au) req = req.lte('created_at', new Date(`${filtre.au}T23:59:59`).toISOString())
      const { data, error, count } = await req
      if (error) throw error
      return { rows: (data ?? []) as Ligne[], total: count ?? 0 }
    },
  })
  const total = q.data?.total ?? 0
  const pages = Math.max(1, Math.ceil(total / PAGE))

  /** L'export passe par la fonction serveur : il exige sa propre permission et s'inscrit lui-même au journal. */
  async function exporter() {
    setExportMsg(null)
    const { data, error } = await supabase.rpc('admin_audit_export', {
      p_actor: filtre.acteur || null,
      p_action: filtre.action || null,
      p_resource_type: null,
      p_resource_id: null,
      p_result: filtre.resultat || null,
      p_from: filtre.du ? new Date(filtre.du).toISOString() : null,
      p_to: filtre.au ? new Date(`${filtre.au}T23:59:59`).toISOString() : null,
      p_limit: 5000,
    })
    if (error) return setExportMsg(messageErreur(error))
    const r = data as { rows?: Record<string, unknown>[]; count?: number; truncated?: boolean }
    const rows = r.rows ?? []
    if (rows.length === 0) return setExportMsg('Aucune ligne à exporter avec ces filtres.')
    telechargerCsv(`audit-${new Date().toISOString().slice(0, 10)}.csv`, versCsv(Object.keys(rows[0]), rows))
    setExportMsg(`${rows.length} ligne(s) exportée(s)${r.truncated ? ' — limite de 5 000 atteinte, affinez les filtres.' : '.'} Cet export est inscrit au journal.`)
  }

  const champ = (k: keyof Filtre, label: string, type = 'text') => (
    <label className="text-xs text-slate-500">
      {label}
      <input className="input mt-1" type={type} value={saisie[k]} onChange={(e) => setSaisie({ ...saisie, [k]: e.target.value })} />
    </label>
  )

  return (
    <section>
      <h1 className="mb-1 text-xl font-semibold">Journal d'audit</h1>
      <p className="mb-4 text-sm text-slate-500">Lecture seule. Le journal est écrit par le serveur, jamais par cette console.</p>
      <form
        className="mb-4 flex flex-wrap items-end gap-2"
        onSubmit={(e) => {
          e.preventDefault()
          setPage(0)
          setFiltre({ ...saisie, action: saisie.action.trim().toUpperCase(), acteur: saisie.acteur.trim() })
        }}
      >
        {champ('action', 'Action exacte (ex. REPORT_ASSIGNED)')}
        {champ('acteur', 'Identifiant de l\'acteur')}
        <label className="text-xs text-slate-500">
          Résultat
          <select className="input mt-1" value={saisie.resultat} onChange={(e) => setSaisie({ ...saisie, resultat: e.target.value })}>
            <option value="">Tous</option>
            <option value="success">success</option>
            <option value="denied">denied</option>
            <option value="failed">failed</option>
            <option value="partial">partial</option>
          </select>
        </label>
        {champ('du', 'Du', 'date')}
        {champ('au', 'Au', 'date')}
        <button className="btn btn-primary">Filtrer</button>
        <button type="button" className="btn btn-ghost" onClick={() => { setSaisie(VIDE); setFiltre(VIDE); setPage(0) }}>Réinitialiser</button>
        {peut(PERM.auditExport) && (
          <button type="button" className="btn btn-ghost" onClick={() => void exporter()}>Exporter (CSV)</button>
        )}
      </form>
      {exportMsg && <p role="status" className="mb-3 text-sm text-blue-800">{exportMsg}</p>}
      {q.isLoading && <Loading />}
      {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
      {q.isSuccess && q.data.rows.length === 0 && <Empty>Aucune entrée.</Empty>}
      {q.isSuccess && q.data.rows.length > 0 && (
        <div className="card overflow-x-auto p-0">
          <table className="w-full">
            <thead className="border-b border-slate-200 bg-slate-50">
              <tr>
                <th className="th">Date</th>
                <th className="th">Acteur</th>
                <th className="th">Action</th>
                <th className="th">Cible</th>
                <th className="th">Résultat</th>
                <th className="th">Motif</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {q.data.rows.map((l) => (
                <tr key={l.id}>
                  <td className="td whitespace-nowrap">{fmtDate(l.created_at)}</td>
                  <td className="td">{l.admin_name ?? l.admin_id}</td>
                  <td className="td font-mono text-xs">{l.action}</td>
                  <td className="td">{[l.target_type, l.target_id].filter(Boolean).join(' · ') || '—'}</td>
                  <td className="td">
                    <Badge tone={l.result === 'denied' || l.result === 'failed' ? 'red' : 'green'}>{l.result ?? 'success'}</Badge>
                  </td>
                  <td className="td">{l.reason_code ?? '—'}</td>
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
