import { useState, type FormEvent } from 'react'
import { useMutation } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { messageErreur } from '../lib/erreurs'

export const MOTIFS_CONTACT: [string, string][] = [
  ['info_request', "Demande de complément d'information"],
  ['account_issue', 'Problème de compte'],
  ['profile_update', 'Mise à jour du profil'],
  ['admin_notice', 'Information administrative'],
  ['decision', 'Décision administrative'],
  ['other', 'Autre motif autorisé'],
]

/**
 * Message administratif individuel. Le serveur ouvre un ticket au nom du membre : il le lit dans l'aide de l'application
 * et peut y répondre. La notification qu'il reçoit ne reprend pas le texte.
 */
export default function ContacterMembre({ membreId, nom }: { membreId: string; nom: string }) {
  const [motif, setMotif] = useState('')
  const [sujet, setSujet] = useState('')
  const [message, setMessage] = useState('')

  const m = useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase.rpc('member_admin_contact', {
        p_member_id: membreId, p_reason: motif, p_subject: sujet, p_body: message,
      })
      if (error) throw error
      return data as string
    },
    onSuccess: () => { setMotif(''); setSujet(''); setMessage('') },
  })

  const envoyer = (e: FormEvent) => {
    e.preventDefault()
    if (confirm(`Envoyer ce message à ${nom} ? Il sera visible dans l'aide de l'application et inscrit au journal.`)) m.mutate()
  }

  return (
    <form onSubmit={envoyer} className="space-y-2" aria-label="Contacter ce membre">
      <h3 className="text-sm font-semibold">Contacter ce membre</h3>
      <select className="input" aria-label="Motif du contact" value={motif} onChange={(e) => setMotif(e.target.value)} required>
        <option value="">Motif du contact…</option>
        {MOTIFS_CONTACT.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
      </select>
      <input className="input" placeholder="Sujet" minLength={5} maxLength={120} value={sujet} onChange={(e) => setSujet(e.target.value)} required />
      <textarea className="input" rows={5} placeholder="Message" minLength={10} maxLength={4000} value={message} onChange={(e) => setMessage(e.target.value)} required />
      <button className="btn btn-primary" disabled={m.isPending}>Envoyer</button>
      {m.isSuccess && <p role="status" className="text-sm text-green-700">Message envoyé : un ticket a été ouvert au nom du membre (page Support).</p>}
      {m.isError && <p role="alert" className="text-sm text-red-600">{messageErreur(m.error)}</p>}
      <p className="text-xs text-slate-500">Maximum 3 messages par membre et par 24 h. Le texte n'apparaît jamais dans le journal, seulement le motif.</p>
    </form>
  )
}
