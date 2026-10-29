import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { messageErreur } from '../lib/erreurs'
import { analyserSection } from '../lib/reglages'

/** Brouillon d'une démarche consulaire. Le serveur fusionne avec la version publiée, valide le contenu et exige une source. */
export default function NouvelleDemarche({ onDone }: { onDone: () => void }) {
  const qc = useQueryClient()
  const [id, setId] = useState('')
  const [contenu, setContenu] = useState('{\n  \n}')
  const [url, setUrl] = useState('')
  const [editeur, setEditeur] = useState('')
  const [verifie, setVerifie] = useState('')
  const [revue, setRevue] = useState('')
  const [motif, setMotif] = useState('')
  const [erreurLocale, setErreurLocale] = useState<string | null>(null)

  const m = useMutation({
    mutationFn: async (payload: Record<string, unknown>) => {
      const { error } = await supabase.rpc('demarche_draft_save', {
        p_demarche_id: id.trim(),
        p_payload: payload,
        p_source_url: url.trim(),
        p_source_publisher: editeur.trim(),
        p_verified_at: new Date(verifie).toISOString(),
        p_next_review_at: revue ? new Date(revue).toISOString() : null,
        p_change_reason: motif.trim(),
      })
      if (error) throw error
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['liste', 'demarches_brouillons'] })
      onDone()
    },
  })

  const envoyer = (e: FormEvent) => {
    e.preventDefault()
    const r = analyserSection(contenu)
    if (!r.ok) return setErreurLocale(r.erreur)
    setErreurLocale(null)
    m.mutate(r.valeur)
  }

  return (
    <form onSubmit={envoyer} className="card space-y-2 self-start" aria-label="Nouveau brouillon de démarche">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold">Brouillon de démarche</h2>
        <button type="button" className="btn btn-ghost px-2 py-1" onClick={onDone} aria-label="Fermer">✕</button>
      </div>
      <input className="input" placeholder="Identifiant de la démarche" value={id} onChange={(e) => setId(e.target.value)} required />
      <label className="block text-sm">Contenu à modifier (JSON, fusionné avec la version publiée)
        <textarea className="input mt-1 font-mono text-xs" rows={8} value={contenu} onChange={(e) => setContenu(e.target.value)} spellCheck={false} />
      </label>
      <input className="input" type="url" placeholder="Source officielle (lien)" value={url} onChange={(e) => setUrl(e.target.value)} required />
      <input className="input" placeholder="Organisme source" value={editeur} onChange={(e) => setEditeur(e.target.value)} required />
      <label className="block text-xs text-slate-500">Vérifié le
        <input className="input mt-1" type="date" value={verifie} onChange={(e) => setVerifie(e.target.value)} required />
      </label>
      <label className="block text-xs text-slate-500">Prochaine revue (facultatif)
        <input className="input mt-1" type="date" value={revue} onChange={(e) => setRevue(e.target.value)} />
      </label>
      <input className="input" placeholder="Motif du changement" value={motif} onChange={(e) => setMotif(e.target.value)} required />
      <button className="btn btn-primary" disabled={m.isPending}>Enregistrer le brouillon</button>
      {erreurLocale && <p role="alert" className="text-sm text-red-600">{erreurLocale}</p>}
      {m.isError && <p role="alert" className="text-sm text-red-600">{messageErreur(m.error)}</p>}
      <p className="text-xs text-slate-500">Une procédure n'est jamais présentée comme à jour sans source ni date de vérification.</p>
    </form>
  )
}
