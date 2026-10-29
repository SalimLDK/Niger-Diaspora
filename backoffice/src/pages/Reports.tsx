import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { messageErreur, supabase } from '../lib/supabase'
import DossierExtras from '../components/DossierExtras'
import { Badge, Empty, ErrorBox, Loading, fmtDate } from '../components/States'

interface Signalement {
  id: string
  target_type: string
  target_id: string
  reason: string
  description: string | null
  status: string
  assigned_to: string | null
  reason_code: string | null
  admin_note: string | null
  created_at: string
}
interface Transition {
  from_status: string
  to_status: string
  permission: string
  needs_reason: boolean
  needs_note: boolean
  needs_action: boolean
}

/** Miroir d'affichage des motifs normalisés ; le serveur reste seul juge. */
export const MOTIFS: Record<string, string[]> = {
  dismissed: ['rule_not_violated', 'insufficient_evidence', 'content_unavailable', 'duplicate', 'out_of_scope'],
  resolved: ['content_removed', 'user_warned', 'user_suspended', 'user_banned', 'correction_requested'],
  escalated: ['high_risk', 'conflict_of_interest', 'legal', 'security', 'uncertain'],
}

const STATUTS = ['pending', 'reviewing', 'escalated', 'resolved', 'dismissed']
const LIBELLE: Record<string, string> = {
  pending: 'Nouveau',
  reviewing: 'En examen',
  escalated: 'Escaladé',
  resolved: 'Décidé',
  dismissed: 'Rejeté',
}
const TONE: Record<string, 'slate' | 'blue' | 'amber' | 'green'> = {
  pending: 'blue',
  reviewing: 'amber',
  escalated: 'amber',
  resolved: 'green',
  dismissed: 'slate',
}

export default function Reports() {
  const [statut, setStatut] = useState('pending')
  const [sel, setSel] = useState<Signalement | null>(null)

  const liste = useQuery({
    queryKey: ['signalements', statut],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('reports')
        .select('id,target_type,target_id,reason,description,status,assigned_to,reason_code,admin_note,created_at')
        .eq('status', statut)
        .order('created_at', { ascending: true })
        .limit(100)
      if (error) throw error
      return (data ?? []) as Signalement[]
    },
  })

  return (
    <section className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <div>
        <h1 className="mb-4 text-xl font-semibold">Signalements</h1>
        <div className="mb-3 flex flex-wrap gap-2" role="tablist" aria-label="Statut">
          {STATUTS.map((s) => (
            <button
              key={s}
              role="tab"
              aria-selected={s === statut}
              className={`btn ${s === statut ? 'btn-primary' : 'btn-ghost'}`}
              onClick={() => {
                setStatut(s)
                setSel(null)
              }}
            >
              {LIBELLE[s]}
            </button>
          ))}
        </div>
        {liste.isLoading && <Loading />}
        {liste.isError && <ErrorBox error={liste.error} onRetry={() => void liste.refetch()} />}
        {liste.isSuccess && liste.data.length === 0 && <Empty>Aucun dossier dans cet état.</Empty>}
        <ul className="space-y-2">
          {liste.data?.map((r) => (
            <li key={r.id}>
              <button
                onClick={() => setSel(r)}
                className={`card w-full text-left hover:border-brand ${sel?.id === r.id ? 'border-brand' : ''}`}
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium">
                    {r.target_type} · {r.reason}
                  </span>
                  <Badge tone={TONE[r.status] ?? 'slate'}>{LIBELLE[r.status] ?? r.status}</Badge>
                </div>
                <p className="mt-1 text-xs text-slate-500">Reçu le {fmtDate(r.created_at)}</p>
              </button>
            </li>
          ))}
        </ul>
      </div>
      {sel ? <Dossier key={sel.id} r={sel} onDone={() => setSel(null)} /> : <p className="text-sm text-slate-500">Sélectionnez un dossier.</p>}
    </section>
  )
}

function Dossier({ r, onDone }: { r: Signalement; onDone: () => void }) {
  const qc = useQueryClient()
  const [to, setTo] = useState('')
  const [motif, setMotif] = useState('')
  const [note, setNote] = useState('')
  const [action, setAction] = useState('')

  const trans = useQuery({
    queryKey: ['transitions', r.status],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('moderation_report_transitions')
        .select('from_status,to_status,permission,needs_reason,needs_note,needs_action')
        .eq('from_status', r.status)
      if (error) throw error
      const all = (data ?? []) as Transition[]
      const ok = await Promise.all(
        all.map(async (t) => {
          const { data: a } = await supabase.rpc('admin_has_permission', { perm: t.permission })
          return a === true ? t : null
        }),
      )
      return ok.filter((t): t is Transition => t !== null)
    },
  })
  const t = trans.data?.find((x) => x.to_status === to)

  const m = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.rpc('signalement_transition', {
        p_report_id: r.id,
        p_to: to,
        p_reason_code: t?.needs_reason ? motif : null,
        p_note: note || null,
        p_action_taken: t?.needs_action ? action : null,
      })
      if (error) throw error
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['signalements'] })
      await qc.invalidateQueries({ queryKey: ['dashboard-tasks'] })
      onDone()
    },
  })

  return (
    <aside className="card space-y-3 self-start" aria-label="Dossier">
      <h2 className="font-semibold">Dossier</h2>
      <dl className="space-y-1 text-sm">
        <div><dt className="inline text-slate-500">Objet : </dt><dd className="inline">{r.target_type} · {r.target_id}</dd></div>
        <div><dt className="inline text-slate-500">Motif du déclarant : </dt><dd className="inline">{r.reason}</dd></div>
        {r.description && <div><dt className="text-slate-500">Description</dt><dd className="whitespace-pre-wrap">{r.description}</dd></div>}
        {r.admin_note && <div><dt className="text-slate-500">Note interne</dt><dd className="whitespace-pre-wrap">{r.admin_note}</dd></div>}
      </dl>
      <hr />
      {trans.isLoading && <Loading />}
      {trans.isError && <ErrorBox error={trans.error} />}
      {trans.isSuccess && trans.data.length === 0 && (
        <p className="text-sm text-slate-500">Aucune action disponible pour votre rôle dans cet état.</p>
      )}
      {trans.isSuccess && trans.data.length > 0 && (
        <form
          className="space-y-2"
          onSubmit={(e) => {
            e.preventDefault()
            m.mutate()
          }}
        >
          <label className="block text-sm">
            Action
            <select className="input mt-1" value={to} onChange={(e) => { setTo(e.target.value); setMotif('') }} required>
              <option value="">Choisir…</option>
              {trans.data.map((x) => (
                <option key={x.to_status} value={x.to_status}>
                  {LIBELLE[x.to_status] ?? x.to_status}
                </option>
              ))}
            </select>
          </label>
          {t?.needs_reason && (
            <label className="block text-sm">
              Motif
              <select className="input mt-1" value={motif} onChange={(e) => setMotif(e.target.value)} required>
                <option value="">Choisir…</option>
                {(MOTIFS[to] ?? []).map((c) => <option key={c}>{c}</option>)}
              </select>
            </label>
          )}
          {t?.needs_action && (
            <label className="block text-sm">
              Mesure appliquée
              <input className="input mt-1" value={action} onChange={(e) => setAction(e.target.value)} required />
            </label>
          )}
          {t && (
            <label className="block text-sm">
              Justification{t.needs_note ? '' : ' (facultative)'}
              <textarea className="input mt-1" rows={3} maxLength={2000} value={note} onChange={(e) => setNote(e.target.value)} required={t.needs_note} />
            </label>
          )}
          <button className="btn btn-primary" disabled={!t || m.isPending}>Valider</button>
          {m.isError && <p role="alert" className="text-sm text-red-600">{messageErreur(m.error)}</p>}
        </form>
      )}
      <DossierExtras reportId={r.id} />
    </aside>
  )
}
