import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { Badge, ErrorBox, Loading, fmtDate } from './States'
import { FormMotif, useAction } from './Panneaux'
import { messageErreur } from '../lib/erreurs'

interface Demande { id: string; recipient_kind: string; questions: string; due_at: string | null; status: string; response: string | null; sent_at: string | null }
interface Recours { id: string; argument: string; status: string; received_at: string; decision_note: string | null }

const ISSUES: [string, string][] = [
  ['upheld', 'Décision confirmée'], ['reduced', 'Sanction réduite'],
  ['annulled', 'Décision annulée'], ['sent_back', 'Renvoyé pour nouvel examen'],
]

function Erreur({ e }: { e: unknown }) {
  return e ? <p role="alert" className="text-sm text-red-600">{messageErreur(e)}</p> : null
}

/** Demandes d'informations et recours rattachés à un signalement. Le serveur impose droits, états et séparation des rôles. */
export default function DossierExtras({ reportId }: { reportId: string }) {
  const infos = useQuery({
    queryKey: ['detail', 'infos', reportId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('moderation_info_requests')
        .select('id,recipient_kind,questions,due_at,status,response,sent_at')
        .eq('report_id', reportId).order('created_at', { ascending: false })
      if (error) throw error
      return (data ?? []) as Demande[]
    },
  })
  const recours = useQuery({
    queryKey: ['detail', 'recours', reportId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('moderation_appeals')
        .select('id,argument,status,received_at,decision_note')
        .eq('report_id', reportId).order('received_at', { ascending: false })
      if (error) throw error
      return (data ?? []) as Recours[]
    },
  })
  const creer = useAction('moderation_info_request_create')
  const envoyer = useAction('moderation_info_request_send')
  const prendre = useAction('moderation_appeal_take')
  const decider = useAction('moderation_appeal_decide')

  const [kind, setKind] = useState('reporter')
  const [questions, setQuestions] = useState('')
  const [echeance, setEcheance] = useState('')
  const [issue, setIssue] = useState<Record<string, string>>({})

  return (
    <div className="space-y-3">
      <hr />
      <h3 className="text-sm font-semibold">Demandes d'informations</h3>
      {infos.isLoading && <Loading />}
      {infos.isError && <ErrorBox error={infos.error} />}
      {infos.data?.length === 0 && <p className="text-sm text-slate-500">Aucune demande.</p>}
      <ul className="space-y-2">
        {infos.data?.map((d) => (
          <li key={d.id} className="rounded border border-slate-200 p-2 text-sm">
            <p><Badge tone="blue">{d.status}</Badge> {d.recipient_kind === 'reporter' ? 'Déclarant' : 'Membre visé'} · échéance {fmtDate(d.due_at)}</p>
            <p className="mt-1 whitespace-pre-wrap">{d.questions}</p>
            {d.response && <p className="mt-1 rounded bg-slate-50 p-1">Réponse : {d.response}</p>}
            {d.status === 'draft' && (
              <button className="btn btn-primary mt-2" disabled={envoyer.isPending} onClick={() => envoyer.mutate({ p_id: d.id })}>Envoyer</button>
            )}
          </li>
        ))}
      </ul>
      <Erreur e={envoyer.error} />
      <form className="space-y-2" onSubmit={(e) => {
        e.preventDefault()
        creer.mutate({ p_report_id: reportId, p_recipient_kind: kind, p_questions: questions, p_due_at: new Date(echeance).toISOString() },
          { onSuccess: () => { setQuestions(''); setEcheance('') } })
      }}>
        <select className="input" value={kind} onChange={(e) => setKind(e.target.value)} aria-label="Destinataire">
          <option value="reporter">Au déclarant</option>
          <option value="reported">Au membre visé</option>
        </select>
        <textarea className="input" rows={2} maxLength={1000} placeholder="Questions" value={questions} onChange={(e) => setQuestions(e.target.value)} required />
        <label className="block text-xs text-slate-500">Réponse attendue avant le
          <input className="input mt-1" type="date" value={echeance} onChange={(e) => setEcheance(e.target.value)} required />
        </label>
        <button className="btn btn-ghost" disabled={creer.isPending}>Préparer la demande</button>
        <Erreur e={creer.error} />
      </form>

      <hr />
      <h3 className="text-sm font-semibold">Recours</h3>
      {recours.isLoading && <Loading />}
      {recours.isError && <ErrorBox error={recours.error} />}
      {recours.data?.length === 0 && <p className="text-sm text-slate-500">Aucun recours.</p>}
      <ul className="space-y-2">
        {recours.data?.map((r) => (
          <li key={r.id} className="rounded border border-slate-200 p-2 text-sm">
            <p><Badge tone="amber">{r.status}</Badge> reçu le {fmtDate(r.received_at)}</p>
            <p className="mt-1 whitespace-pre-wrap">{r.argument}</p>
            {r.decision_note && <p className="mt-1 text-slate-500">Décision : {r.decision_note}</p>}
            {r.status === 'received' && (
              <button className="btn btn-ghost mt-2" disabled={prendre.isPending} onClick={() => prendre.mutate({ p_id: r.id })}>Prendre en charge</button>
            )}
            {r.status === 'in_review' && (
              <div className="mt-2 space-y-2">
                <select className="input" value={issue[r.id] ?? ''} onChange={(e) => setIssue({ ...issue, [r.id]: e.target.value })} aria-label="Issue">
                  <option value="">Issue…</option>
                  {ISSUES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                </select>
                {issue[r.id] && (
                  <FormMotif libelle="Motivation" bouton="Décider" pending={decider.isPending} error={decider.error}
                    onSubmit={(t) => decider.mutate({ p_id: r.id, p_outcome: issue[r.id], p_note: t })} />
                )}
              </div>
            )}
          </li>
        ))}
      </ul>
      <Erreur e={prendre.error} />
    </div>
  )
}
