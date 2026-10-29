import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { messageErreur } from '../lib/erreurs'

const TYPES: [string, string][] = [
  ['official_info', 'Information officielle'],
  ['transactional', 'Transactionnelle'],
  ['security', 'Sécurité'],
  ['promotional', 'Promotionnelle'],
]

/** Rédige un brouillon puis le soumet à la relecture d'un autre administrateur. L'envoi n'a lieu qu'après approbation. */
export default function NouvelleCampagne({ onDone }: { onDone: () => void }) {
  const qc = useQueryClient()
  const [type, setType] = useState('official_info')
  const [titre, setTitre] = useState('')
  const [texte, setTexte] = useState('')
  const [ciblage, setCiblage] = useState<'all' | 'country'>('country')
  const [pays, setPays] = useState('')
  const [soumettre, setSoumettre] = useState(true)

  const m = useMutation({
    mutationFn: async () => {
      const audience = ciblage === 'all' ? { kind: 'all' } : { kind: 'country', country: pays.trim() }
      const { data, error } = await supabase.rpc('campaign_save', {
        p_id: null, p_type: type, p_title: titre, p_body: texte, p_audience: audience,
      })
      if (error) throw error
      if (soumettre) {
        const { error: e2 } = await supabase.rpc('campaign_submit', { p_id: data as string })
        if (e2) throw e2
      }
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['liste', 'campaigns'] })
      await qc.invalidateQueries({ queryKey: ['dashboard-tasks'] })
      onDone()
    },
  })

  const envoyer = (e: FormEvent) => {
    e.preventDefault()
    if (ciblage === 'all' && !confirm("Cette campagne visera TOUS les membres (après approbation). Continuer ?")) return
    m.mutate()
  }

  return (
    <form onSubmit={envoyer} className="card space-y-3 self-start" aria-label="Nouvelle campagne">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold">Nouvelle campagne</h2>
        <button type="button" className="btn btn-ghost px-2 py-1" onClick={onDone} aria-label="Fermer">✕</button>
      </div>
      <select className="input" value={type} onChange={(e) => setType(e.target.value)} aria-label="Type">
        {TYPES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
      </select>
      <label className="block text-sm">Titre (3 à 80 caractères)
        <input className="input mt-1" minLength={3} maxLength={80} value={titre} onChange={(e) => setTitre(e.target.value)} required />
      </label>
      <label className="block text-sm">Texte (10 à 300 caractères)
        <textarea className="input mt-1" rows={4} minLength={10} maxLength={300} value={texte} onChange={(e) => setTexte(e.target.value)} required />
        <span className="text-xs text-slate-400">{texte.length}/300 · aucun contenu privé dans une notification</span>
      </label>
      <label className="block text-sm">Audience
        <select className="input mt-1" value={ciblage} onChange={(e) => setCiblage(e.target.value as 'all' | 'country')}>
          <option value="country">Un pays</option>
          <option value="all">Tous les membres</option>
        </select>
      </label>
      {ciblage === 'country' && (
        <input className="input" placeholder="Pays tel qu'enregistré (ex. France)" value={pays} onChange={(e) => setPays(e.target.value)} required />
      )}
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" checked={soumettre} onChange={(e) => setSoumettre(e.target.checked)} />
        Soumettre tout de suite à la relecture
      </label>
      <button className="btn btn-primary" disabled={m.isPending}>{soumettre ? 'Créer et soumettre' : 'Enregistrer le brouillon'}</button>
      {m.isError && <p role="alert" className="text-sm text-red-600">{messageErreur(m.error)}</p>}
      <p className="text-xs text-slate-500">L'audience est résolue côté serveur à l'envoi ; les comptes suspendus sont exclus.</p>
    </form>
  )
}
