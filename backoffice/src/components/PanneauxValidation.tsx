import { useState } from 'react'
import { messageErreur } from '../lib/supabase'
import { FormMotif, Panneau, useAction } from './Panneaux'

function Erreur({ e }: { e: unknown }) {
  return e ? <p role="alert" className="text-sm text-red-600">{messageErreur(e)}</p> : null
}

export interface CampagneLigne { id: string; type: string; title: string; body: string; status: string; review_note: string | null }

export function PanneauCampagne({ c, onClose }: { c: CampagneLigne; onClose: () => void }) {
  const decider = useAction('campaign_review', onClose)
  const annuler = useAction('campaign_cancel', onClose)
  const [rejet, setRejet] = useState(false)
  return (
    <Panneau titre={c.title} onClose={onClose}>
      <p className="text-xs text-slate-500">Type : {c.type} · statut : {c.status}</p>
      <p className="whitespace-pre-wrap text-sm">{c.body}</p>
      {c.review_note && <p className="text-sm text-slate-500">Note de relecture : {c.review_note}</p>}
      {c.status === 'pending_approval' && (
        <>
          <p className="text-xs text-slate-500">La séparation auteur / approbateur est vérifiée par le serveur.</p>
          <button className="btn btn-primary" disabled={decider.isPending}
            onClick={() => decider.mutate({ p_id: c.id, p_decision: 'approve', p_note: null })}>Approuver</button>{' '}
          <button className="btn btn-ghost" onClick={() => setRejet((v) => !v)}>Rejeter…</button>
          {rejet && (
            <FormMotif libelle="Motif du rejet" bouton="Confirmer le rejet" danger pending={decider.isPending} error={decider.error}
              onSubmit={(t) => decider.mutate({ p_id: c.id, p_decision: 'reject', p_note: t })} />
          )}
          <Erreur e={!rejet ? decider.error : null} />
        </>
      )}
      {['draft', 'pending_approval', 'approved'].includes(c.status) && (
        <FormMotif libelle="Annuler la campagne (motif)" bouton="Annuler la campagne" danger pending={annuler.isPending} error={annuler.error}
          onSubmit={(t) => { if (confirm('Annuler cette campagne ?')) annuler.mutate({ p_id: c.id, p_reason: t }) }} />
      )}
      <p className="text-xs text-slate-500">La création et l'envoi restent dans le panneau actuel.</p>
    </Panneau>
  )
}

export interface DemarcheLigne { id: string; demarche_id: string; status: string; change_reason: string | null; review_note: string | null }

export function PanneauDemarche({ d, onClose }: { d: DemarcheLigne; onClose: () => void }) {
  const decider = useAction('demarche_review', onClose)
  const publier = useAction('demarche_publish', onClose)
  const [rejet, setRejet] = useState(false)
  return (
    <Panneau titre={`Démarche ${d.demarche_id}`} onClose={onClose}>
      <p className="text-xs text-slate-500">Statut : {d.status}</p>
      {d.change_reason && <p className="text-sm">Motif du changement : {d.change_reason}</p>}
      {d.review_note && <p className="text-sm text-slate-500">Note de relecture : {d.review_note}</p>}
      {d.status === 'pending' && (
        <>
          <button className="btn btn-primary" disabled={decider.isPending}
            onClick={() => decider.mutate({ p_draft_id: d.id, p_decision: 'approve', p_note: null })}>Approuver</button>{' '}
          <button className="btn btn-ghost" onClick={() => setRejet((v) => !v)}>Rejeter…</button>
          {rejet && (
            <FormMotif libelle="Motif du rejet" bouton="Confirmer le rejet" danger pending={decider.isPending} error={decider.error}
              onSubmit={(t) => decider.mutate({ p_draft_id: d.id, p_decision: 'reject', p_note: t })} />
          )}
          <Erreur e={!rejet ? decider.error : null} />
        </>
      )}
      {d.status === 'approved' && (
        <>
          <button className="btn btn-primary" disabled={publier.isPending}
            onClick={() => { if (confirm('Publier cette version ?')) publier.mutate({ p_draft_id: d.id }) }}>Publier</button>
          <Erreur e={publier.error} />
        </>
      )}
      <p className="text-xs text-slate-500">La rédaction du contenu reste dans le panneau actuel.</p>
    </Panneau>
  )
}
