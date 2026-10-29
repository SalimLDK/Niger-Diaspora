import { useState } from 'react'
import { messageErreur } from '../lib/erreurs'
import { FormMotif, Panneau, useAction } from './Panneaux'

function Erreur({ e }: { e: unknown }) {
  return e ? <p role="alert" className="text-sm text-red-600">{messageErreur(e)}</p> : null
}

/* --------------------------------------------------------------- Incidents */

export interface IncidentLigne { id: string; title: string; severity: string; status: string }
const ETATS: Record<string, [string, string][]> = {
  open: [['contained', 'Contenu'], ['resolved', 'Résolu']],
  contained: [['resolved', 'Résolu']],
  resolved: [['closed', 'Clos']],
}

export function PanneauIncident({ i, onClose }: { i: IncidentLigne; onClose: () => void }) {
  const note = useAction('security_incident_note')
  const gravite = useAction('security_incident_set_severity')
  const transition = useAction('security_incident_transition', onClose)
  const [to, setTo] = useState('')
  const [sev, setSev] = useState('')
  const [cause, setCause] = useState('')
  const [actions, setActions] = useState('')
  const [lecons, setLecons] = useState('')
  const [justif, setJustif] = useState('')

  return (
    <Panneau titre={i.title} onClose={onClose}>
      <p className="text-xs text-slate-500">Gravité : {i.severity} · état : {i.status}</p>
      <FormMotif libelle="Note au dossier" bouton="Ajouter la note" pending={note.isPending} error={note.error}
        onSubmit={(t) => note.mutate({ p_id: i.id, p_body: t })} />
      <hr />
      <form className="space-y-2" onSubmit={(e) => { e.preventDefault(); gravite.mutate({ p_id: i.id, p_severity: sev, p_reason: justif }) }}>
        <select className="input" value={sev} onChange={(e) => setSev(e.target.value)} required aria-label="Nouvelle gravité">
          <option value="">Changer la gravité…</option>
          {['low', 'medium', 'high', 'critical'].map((s) => <option key={s}>{s}</option>)}
        </select>
        <input className="input" placeholder="Motif du changement" value={justif} onChange={(e) => setJustif(e.target.value)} required />
        <button className="btn btn-ghost" disabled={gravite.isPending}>Appliquer</button>
        <Erreur e={gravite.error} />
      </form>
      <hr />
      {(ETATS[i.status] ?? []).length > 0 && (
        <form className="space-y-2" onSubmit={(e) => {
          e.preventDefault()
          transition.mutate({ p_id: i.id, p_to: to, p_note: justif, p_cause: cause || null, p_actions: actions || null, p_lessons: lecons || null })
        }}>
          <select className="input" value={to} onChange={(e) => setTo(e.target.value)} required aria-label="Nouvel état">
            <option value="">Faire avancer l'incident…</option>
            {(ETATS[i.status] ?? []).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </select>
          <textarea className="input" rows={2} placeholder="Note (obligatoire)" value={justif} onChange={(e) => setJustif(e.target.value)} required />
          {(to === 'resolved' || to === 'closed') && (
            <>
              <input className="input" placeholder="Cause" value={cause} onChange={(e) => setCause(e.target.value)} />
              <input className="input" placeholder="Actions correctives" value={actions} onChange={(e) => setActions(e.target.value)} />
              <input className="input" placeholder="Leçons tirées" value={lecons} onChange={(e) => setLecons(e.target.value)} />
            </>
          )}
          <button className="btn btn-primary" disabled={transition.isPending}>Valider</button>
          <Erreur e={transition.error} />
        </form>
      )}
    </Panneau>
  )
}

/* ---------------------------------------------------------------- Annuaire */

export interface FicheLigne { id: string; name: string; is_verified: boolean; is_active: boolean }

export function PanneauFiche({ f, onClose }: { f: FicheLigne; onClose: () => void }) {
  const verifier = useAction('business_admin_verify', onClose)
  const retirer = useAction('business_admin_unverify', onClose)
  const archiver = useAction('business_admin_archive', onClose)
  const restaurer = useAction('business_admin_restore', onClose)
  const [source, setSource] = useState('')

  return (
    <Panneau titre={f.name || 'Fiche sans nom'} onClose={onClose}>
      <p className="text-xs text-slate-500">{f.is_verified ? 'Vérifiée' : 'Non vérifiée'} · {f.is_active ? 'active' : 'archivée'}</p>
      {!f.is_verified && f.is_active && (
        <form className="space-y-2" onSubmit={(e) => { e.preventDefault(); verifier.mutate({ p_id: f.id, p_source: source, p_next_review: null }) }}>
          <label className="block text-sm">Source de la vérification
            <input className="input mt-1" value={source} onChange={(e) => setSource(e.target.value)} placeholder="Ex. site officiel, appel téléphonique" required />
          </label>
          <button className="btn btn-primary" disabled={verifier.isPending}>Attribuer le badge</button>
          <Erreur e={verifier.error} />
        </form>
      )}
      {f.is_verified && (
        <FormMotif libelle="Retirer le badge (motif)" bouton="Retirer le badge" danger multiline={false} pending={retirer.isPending} error={retirer.error}
          onSubmit={(t) => retirer.mutate({ p_id: f.id, p_reason: t })} />
      )}
      {f.is_active ? (
        <FormMotif libelle="Archiver la fiche (motif)" bouton="Archiver" danger multiline={false} pending={archiver.isPending} error={archiver.error}
          onSubmit={(t) => { if (confirm('Archiver cette fiche ? Elle ne sera pas supprimée.')) archiver.mutate({ p_id: f.id, p_reason: t }) }} />
      ) : (
        <FormMotif libelle="Restaurer la fiche (motif)" bouton="Restaurer" multiline={false} pending={restaurer.isPending} error={restaurer.error}
          onSubmit={(t) => restaurer.mutate({ p_id: f.id, p_reason: t })} />
      )}
    </Panneau>
  )
}

/* -------------------------------------------------------------- Ambassades */

export interface PosteLigne { id: string; name: string; is_verified: boolean; is_suspended: boolean | null; source_url: string | null }

export function PanneauPoste({ p, onClose }: { p: PosteLigne; onClose: () => void }) {
  const verifier = useAction('embassy_admin_verify', onClose)
  const rejeter = useAction('embassy_admin_reject', onClose)
  const suspendre = useAction('embassy_admin_suspend', onClose)
  const reprendre = useAction('embassy_admin_unsuspend', onClose)
  const [url, setUrl] = useState(p.source_url ?? '')
  const [source, setSource] = useState('')

  return (
    <Panneau titre={p.name} onClose={onClose}>
      <p className="text-xs text-slate-500">{p.is_verified ? 'Vérifié' : 'Non vérifié'}{p.is_suspended ? ' · suspendu' : ''}</p>
      {!p.is_verified && (
        <form className="space-y-2" onSubmit={(e) => { e.preventDefault(); verifier.mutate({ p_id: p.id, p_source_url: url, p_source: source }) }}>
          <p className="text-xs text-slate-500">Une source officielle est obligatoire avant publication.</p>
          <input className="input" type="url" placeholder="Lien de la source officielle" value={url} onChange={(e) => setUrl(e.target.value)} required />
          <input className="input" placeholder="Nom de la source" value={source} onChange={(e) => setSource(e.target.value)} required />
          <button className="btn btn-primary" disabled={verifier.isPending}>Marquer comme vérifié</button>
          <Erreur e={verifier.error} />
        </form>
      )}
      {!p.is_verified && (
        <FormMotif libelle="Rejeter (motif)" bouton="Rejeter" danger multiline={false} pending={rejeter.isPending} error={rejeter.error}
          onSubmit={(t) => rejeter.mutate({ p_id: p.id, p_reason: t })} />
      )}
      {p.is_suspended ? (
        <FormMotif libelle="Lever la suspension (motif)" bouton="Rétablir" multiline={false} pending={reprendre.isPending} error={reprendre.error}
          onSubmit={(t) => reprendre.mutate({ p_id: p.id, p_reason: t })} />
      ) : (
        <FormMotif libelle="Suspendre la fiche (motif)" bouton="Suspendre" danger multiline={false} pending={suspendre.isPending} error={suspendre.error}
          onSubmit={(t) => suspendre.mutate({ p_id: p.id, p_reason: t })} />
      )}
    </Panneau>
  )
}
