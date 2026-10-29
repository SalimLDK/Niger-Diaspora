import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
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
      {(c.status === 'approved' || c.status === 'sending') && <EnvoiParLots id={c.id} />}
    </Panneau>
  )
}

export interface DemarcheLigne { id: string; demarche_id: string; status: string; change_reason: string | null; review_note: string | null }

export function PanneauDemarche({ d, onClose }: { d: DemarcheLigne; onClose: () => void }) {
  const decider = useAction('demarche_review', onClose)
  const publier = useAction('demarche_publish', onClose)
  const soumettre = useAction('demarche_submit', onClose)
  const retirer = useAction('demarche_withdraw', onClose)
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
      {d.status === 'draft' && (
        <>
          <button className="btn btn-primary" disabled={soumettre.isPending} onClick={() => soumettre.mutate({ p_draft_id: d.id })}>Soumettre à la relecture</button>
          <Erreur e={soumettre.error} />
        </>
      )}
      {(d.status === 'pending' || d.status === 'draft') && (
        <>
          <button className="btn btn-ghost" disabled={retirer.isPending} onClick={() => retirer.mutate({ p_draft_id: d.id })}>Retirer le brouillon</button>
          <Erreur e={retirer.error} />
        </>
      )}
      {d.status === 'approved' && (
        <>
          <button className="btn btn-primary" disabled={publier.isPending}
            onClick={() => { if (confirm('Publier cette version ?')) publier.mutate({ p_draft_id: d.id }) }}>Publier</button>
          <Erreur e={publier.error} />
        </>
      )}
    </Panneau>
  )
}

/** Envoie les notifications par lots de 200 jusqu'à épuisement ; le serveur borne chaque lot et reprend où il s'est arrêté. */
function EnvoiParLots({ id }: { id: string }) {
  const qc = useQueryClient()
  const [etat, setEtat] = useState<{ traites: number; restants: number | null; fini: boolean } | null>(null)
  const [erreur, setErreur] = useState<unknown>(null)
  const [enCours, setEnCours] = useState(false)

  async function lancer() {
    if (!confirm('Envoyer cette campagne maintenant ? Les notifications partent réellement vers les membres ciblés.')) return
    setErreur(null)
    setEnCours(true)
    let traites = 0
    try {
      for (let i = 0; i < 500; i++) {
        const { data, error } = await supabase.rpc('campaign_send_batch', { p_id: id, p_limit: 200 })
        if (error) throw error
        const r = data as { processed?: number; remaining?: number; status?: string }
        traites += r.processed ?? 0
        const fini = r.status === 'sent' || (r.remaining ?? 0) === 0
        setEtat({ traites, restants: r.remaining ?? null, fini })
        if (fini) break
      }
    } catch (e) {
      setErreur(e)
    } finally {
      setEnCours(false)
      await qc.invalidateQueries({ queryKey: ['liste', 'campaigns'] })
      await qc.invalidateQueries({ queryKey: ['dashboard-tasks'] })
    }
  }

  return (
    <div className="space-y-1">
      <button className="btn btn-primary" disabled={enCours} onClick={() => void lancer()}>{enCours ? 'Envoi en cours…' : 'Envoyer par lots'}</button>
      {etat && <p role="status" className="text-sm">{etat.traites} destinataire(s) traités{etat.fini ? ' — terminé.' : `, ${etat.restants ?? '?'} restant(s).`}</p>}
      <Erreur e={erreur} />
      <p className="text-xs text-slate-500">« Créé » n'est pas « livré » : la livraison réelle se lit côté fournisseur de notifications.</p>
    </div>
  )
}
