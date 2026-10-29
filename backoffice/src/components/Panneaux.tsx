import { useState, type FormEvent, type ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { messageErreur } from '../lib/erreurs'
import { Badge, ErrorBox, Loading, fmtDate } from './States'

/** Appelle une fonction serveur, rafraîchit les listes, affiche l'erreur telle quelle. */
export function useAction(rpc: string, onOk?: () => void) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (args: Record<string, unknown>) => {
      const { error } = await supabase.rpc(rpc, args)
      if (error) throw error
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['liste'] })
      await qc.invalidateQueries({ queryKey: ['dashboard-tasks'] })
      await qc.invalidateQueries({ queryKey: ['detail'] })
      onOk?.()
    },
  })
}

export function Panneau({ titre, children, onClose }: { titre: string; children: ReactNode; onClose: () => void }) {
  return (
    <aside className="card space-y-3 self-start" aria-label={titre}>
      <div className="flex items-start justify-between gap-2">
        <h2 className="font-semibold">{titre}</h2>
        <button className="btn btn-ghost px-2 py-1" onClick={onClose} aria-label="Fermer">✕</button>
      </div>
      {children}
    </aside>
  )
}

function Erreur({ e }: { e: unknown }) {
  return e ? <p role="alert" className="text-sm text-red-600">{messageErreur(e)}</p> : null
}

/** Mini-formulaire à un champ texte, pour une action serveur avec motif. */
export function FormMotif({
  libelle, bouton, requis = true, danger, onSubmit, pending, error, multiline = true, initial = '',
}: {
  libelle: string; bouton: string; requis?: boolean; danger?: boolean
  onSubmit: (texte: string) => void; pending: boolean; error: unknown; multiline?: boolean; initial?: string
}) {
  const [t, setT] = useState(initial)
  const submit = (e: FormEvent) => { e.preventDefault(); onSubmit(t); setT('') }
  return (
    <form onSubmit={submit} className="space-y-2">
      <label className="block text-sm">
        {libelle}
        {multiline
          ? <textarea className="input mt-1" rows={3} maxLength={2000} value={t} onChange={(e) => setT(e.target.value)} required={requis} />
          : <input className="input mt-1" maxLength={500} value={t} onChange={(e) => setT(e.target.value)} required={requis} />}
      </label>
      <button className={`btn ${danger ? 'btn-danger' : 'btn-primary'}`} disabled={pending}>{bouton}</button>
      <Erreur e={error} />
    </form>
  )
}

/* ---------------------------------------------------------------- Support */

interface TicketDetail {
  id: string; subject: string; status: string; category: string | null; description: string | null
  user_name: string | null; messages: unknown; resolution_note: string | null; created_at: string
}
interface TransitionTicket { to_status: string; permission: string; needs_note: boolean }
const LIB_TICKET: Record<string, string> = { in_progress: 'Prendre en charge', resolved: 'Marquer résolu', closed: 'Clore' }

export function PanneauTicket({ id, onClose }: { id: string; onClose: () => void }) {
  const d = useQuery({
    queryKey: ['detail', 'ticket', id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('support_tickets')
        .select('id,subject,status,category,description,user_name,messages,resolution_note,created_at')
        .eq('id', id).single()
      if (error) throw error
      return data as TicketDetail
    },
  })
  const trans = useQuery({
    queryKey: ['detail', 'ticket-transitions', d.data?.status],
    enabled: !!d.data,
    queryFn: async () => {
      const { data, error } = await supabase
        .from('support_ticket_transitions').select('to_status,permission,needs_note').eq('from_status', d.data!.status)
      if (error) throw error
      const res = await Promise.all(((data ?? []) as TransitionTicket[]).map(async (t) => {
        const { data: a } = await supabase.rpc('admin_has_permission', { perm: t.permission })
        return a === true ? t : null
      }))
      return res.filter((t): t is TransitionTicket => t !== null)
    },
  })
  const reponse = useAction('support_ticket_reply')
  const note = useAction('support_ticket_note')
  const transition = useAction('support_ticket_transition')
  const escalade = useAction('support_ticket_escalate')
  const levee = useAction('support_ticket_escalation_resolve')
  const modeles = useQuery({
    queryKey: ['detail', 'modeles'],
    queryFn: async () => {
      const { data, error } = await supabase.from('support_reply_templates').select('id,title,body').order('title')
      if (error) throw error
      return (data ?? []) as { id: string; title: string; body: string }[]
    },
  })
  const [modele, setModele] = useState('')
  const [note2, setNote2] = useState('')
  const [pour, setPour] = useState('')

  const msgs = Array.isArray(d.data?.messages) ? (d.data!.messages as Record<string, unknown>[]) : []

  return (
    <Panneau titre="Ticket" onClose={onClose}>
      {d.isLoading && <Loading />}
      {d.isError && <ErrorBox error={d.error} />}
      {d.data && (
        <>
          <p className="font-medium">{d.data.subject} <Badge tone="blue">{d.data.status}</Badge></p>
          <p className="text-xs text-slate-500">{d.data.user_name ?? 'Membre'} · {fmtDate(d.data.created_at)} · {d.data.category ?? '—'}</p>
          {d.data.description && <p className="whitespace-pre-wrap text-sm">{d.data.description}</p>}
          {msgs.length > 0 && (
            <ul className="max-h-56 space-y-1 overflow-auto rounded bg-slate-50 p-2 text-sm">
              {msgs.map((m, i) => (
                <li key={i}>
                  <span className="text-xs text-slate-500">{String(m.sender ?? m.role ?? m.from ?? '')} </span>
                  {String(m.body ?? m.text ?? m.message ?? '')}
                </li>
              ))}
            </ul>
          )}
          <hr />
          {modeles.data && modeles.data.length > 0 && (
            <select className="input" aria-label="Insérer un modèle" value={modele} onChange={(e) => setModele(e.target.value)}>
              <option value="">Insérer un modèle de réponse…</option>
              {modeles.data.map((m) => <option key={m.id} value={m.id}>{m.title}</option>)}
            </select>
          )}
          <FormMotif key={modele} initial={modeles.data?.find((m) => m.id === modele)?.body ?? ''} libelle="Répondre au membre" bouton="Envoyer la réponse" pending={reponse.isPending} error={reponse.error}
            onSubmit={(t) => reponse.mutate({ p_id: id, p_body: t })} />
          <FormMotif libelle="Note interne (invisible du membre)" bouton="Ajouter la note" pending={note.isPending} error={note.error}
            onSubmit={(t) => note.mutate({ p_id: id, p_body: t })} />
          <FormMotif libelle="Escalader ce ticket (motif)" bouton="Escalader" danger multiline={false} pending={escalade.isPending} error={escalade.error}
            onSubmit={(t) => escalade.mutate({ p_id: id, p_reason: t })} />
          <button className="btn btn-ghost" disabled={levee.isPending} onClick={() => levee.mutate({ p_id: id })}>Lever l'escalade</button>
          {levee.isError && <p role="alert" className="text-sm text-red-600">{messageErreur(levee.error)}</p>}
          <hr />
          {trans.data && trans.data.length > 0 && (
            <form className="space-y-2" onSubmit={(e) => { e.preventDefault(); transition.mutate({ p_id: id, p_to: pour, p_note: note2 || null }) }}>
              <select className="input" value={pour} onChange={(e) => setPour(e.target.value)} required aria-label="Changer l'état">
                <option value="">Changer l'état…</option>
                {trans.data.map((t) => <option key={t.to_status} value={t.to_status}>{LIB_TICKET[t.to_status] ?? t.to_status}</option>)}
              </select>
              <textarea className="input" rows={2} placeholder="Justification" value={note2} onChange={(e) => setNote2(e.target.value)}
                required={!!trans.data.find((t) => t.to_status === pour)?.needs_note} />
              <button className="btn btn-primary" disabled={transition.isPending}>Valider</button>
              <Erreur e={transition.error} />
            </form>
          )}
        </>
      )}
    </Panneau>
  )
}

/* -------------------------------------------------------------- Événements */

export function PanneauEvenement({ id, titre, statut, onClose }: { id: string; titre: string; statut: string; onClose: () => void }) {
  const approuver = useAction('event_admin_approve', onClose)
  const refuser = useAction('event_admin_reject', onClose)
  const annuler = useAction('event_admin_cancel', onClose)
  return (
    <Panneau titre={titre} onClose={onClose}>
      <p className="text-sm text-slate-500">Statut : {statut}</p>
      {statut === 'draft' && (
        <>
          <button className="btn btn-primary" disabled={approuver.isPending} onClick={() => approuver.mutate({ p_id: id, p_note: null })}>Approuver</button>
          <Erreur e={approuver.error} />
          <FormMotif libelle="Motif du refus" bouton="Refuser" danger pending={refuser.isPending} error={refuser.error}
            onSubmit={(t) => refuser.mutate({ p_id: id, p_reason: t })} />
        </>
      )}
      {(statut === 'upcoming' || statut === 'ongoing') && (
        <FormMotif libelle="Motif d'annulation (obligatoire)" bouton="Annuler l'événement" danger pending={annuler.isPending} error={annuler.error}
          onSubmit={(t) => { if (confirm("Annuler cet événement ?")) annuler.mutate({ p_id: id, p_reason: t }) }} />
      )}
      {!['draft', 'upcoming', 'ongoing'].includes(statut) && <p className="text-sm text-slate-500">Aucune action disponible dans cet état.</p>}
    </Panneau>
  )
}

/* ----------------------------------------------------------- Confidentialité */

export function PanneauDemande({ id, statut, onClose }: { id: string; statut: string; onClose: () => void }) {
  const prendre = useAction('privacy_request_take')
  const trans = useAction('privacy_request_transition', onClose)
  const identite = useAction('privacy_request_verify_identity')
  const [to, setTo] = useState('')
  const options = [
    ...(statut === 'identity_verified' ? [['in_progress', 'Démarrer le traitement']] : []),
    ...(statut === 'in_progress' ? [['completed', 'Terminée']] : []),
    ['refused', 'Refuser'], ['cancelled', 'Annuler'],
  ]
  return (
    <Panneau titre="Demande de données" onClose={onClose}>
      <p className="text-sm text-slate-500">Statut : {statut}</p>
      <button className="btn btn-ghost" disabled={prendre.isPending} onClick={() => prendre.mutate({ p_id: id })}>Prendre en charge</button>
      <Erreur e={prendre.error} />
      <form className="space-y-2" onSubmit={(e) => { e.preventDefault() }}>
        <select className="input" value={to} onChange={(e) => setTo(e.target.value)} aria-label="Nouvel état">
          <option value="">Changer l'état…</option>
          {options.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
      </form>
      {to && (
        <FormMotif libelle="Note de traitement" bouton="Valider" danger={to === 'refused'} pending={trans.isPending} error={trans.error}
          onSubmit={(t) => trans.mutate({ p_id: id, p_to: to, p_note: t })} />
      )}
      {statut === 'received' && (
        <FormMotif libelle="Méthode de vérification d'identité (5 caractères min.)" bouton="Identité vérifiée" multiline={false}
          pending={identite.isPending} error={identite.error}
          onSubmit={(t) => identite.mutate({ p_id: id, p_method: t })} />
      )}
    </Panneau>
  )
}

/* ------------------------------------------------------------------ Membres */

interface SignalementMembre { id: string; reason: string; status: string; created_at: string }

export function PanneauMembre({ id, nom, onClose }: { id: string; nom: string; onClose: () => void }) {
  const histo = useQuery({
    queryKey: ['detail', 'membre-signalements', id],
    queryFn: async () => {
      const { data, error } = await supabase.from('reports').select('id,reason,status,created_at')
        .eq('target_type', 'user').eq('target_id', id).order('created_at', { ascending: false }).limit(20)
      if (error) throw error
      return (data ?? []) as SignalementMembre[]
    },
  })
  const [motif, setMotif] = useState('')
  const avertir = useAction('member_admin_warn', onClose)
  const deconnecter = useAction('member_admin_force_logout', onClose)
  return (
    <Panneau titre={nom} onClose={onClose}>
      <h3 className="text-sm font-semibold">Signalements visant ce membre</h3>
      {histo.isLoading && <Loading />}
      {histo.isError && <ErrorBox error={histo.error} />}
      {histo.data?.length === 0 && <p className="text-sm text-slate-500">Aucun signalement.</p>}
      <ul className="space-y-1 text-sm">
        {histo.data?.map((s) => (
          <li key={s.id}><Badge tone="blue">{s.status}</Badge> {s.reason} · {fmtDate(s.created_at)}</li>
        ))}
      </ul>
      <hr />
      <form className="space-y-2" onSubmit={(e) => { e.preventDefault(); avertir.mutate({ p_id: id, p_reason: motif, p_message: motif }) }}>
        <label className="block text-sm">
          Avertissement envoyé au membre
          <textarea className="input mt-1" rows={3} maxLength={500} value={motif} onChange={(e) => setMotif(e.target.value)} required />
        </label>
        <button className="btn btn-primary" disabled={avertir.isPending}>Avertir</button>
        <Erreur e={avertir.error} />
      </form>
      <FormMotif libelle="Déconnecter ce membre de tous ses appareils (motif)" bouton="Forcer la déconnexion" danger multiline={false}
        pending={deconnecter.isPending} error={deconnecter.error}
        onSubmit={(t) => { if (confirm('Déconnecter ce membre ?')) deconnecter.mutate({ p_id: id, p_reason: t }) }} />
      <p className="text-xs text-slate-500">Suspension et bannissement passent par un dossier de signalement.</p>
    </Panneau>
  )
}
