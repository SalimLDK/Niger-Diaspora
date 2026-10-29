import { useState, type FormEvent } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { Badge, Empty, ErrorBox, Loading } from '../components/States'
import { Panneau, useAction } from '../components/Panneaux'
import { messageErreur } from '../lib/erreurs'

interface Modele { id: string; title: string; body: string; category: string }
const CATEGORIES = ['directory', 'privacy', 'complaint', 'appeal', 'security']

/** Modèles de réponse du support : le serveur borne les champs et journalise chaque changement. */
export default function Modeles() {
  const q = useQuery({
    queryKey: ['liste', 'support_reply_templates'],
    queryFn: async () => {
      const { data, error } = await supabase.from('support_reply_templates').select('id,title,body,category').order('title')
      if (error) throw error
      return (data ?? []) as Modele[]
    },
  })
  const [edition, setEdition] = useState<Modele | 'nouveau' | null>(null)

  return (
    <section className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <div>
        <h1 className="mb-1 text-xl font-semibold">Modèles de réponse</h1>
        <p className="mb-4 text-sm text-slate-500">Textes réutilisables insérés dans les réponses du support. Aucun contenu privé ne doit y figurer.</p>
        <button className="btn btn-primary mb-3" onClick={() => setEdition('nouveau')}>Nouveau modèle</button>
        {q.isLoading && <Loading />}
        {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
        {q.isSuccess && q.data.length === 0 && <Empty>Aucun modèle.</Empty>}
        <ul className="space-y-2">
          {q.data?.map((m) => (
            <li key={m.id}>
              <button className="card w-full text-left hover:border-brand" onClick={() => setEdition(m)}>
                <span className="font-medium">{m.title}</span> <Badge>{m.category}</Badge>
                <p className="mt-1 line-clamp-2 text-sm text-slate-500">{m.body}</p>
              </button>
            </li>
          ))}
        </ul>
      </div>
      {edition && <Editeur key={edition === 'nouveau' ? 'n' : edition.id} m={edition === 'nouveau' ? null : edition} onClose={() => setEdition(null)} />}
    </section>
  )
}

function Editeur({ m, onClose }: { m: Modele | null; onClose: () => void }) {
  const [titre, setTitre] = useState(m?.title ?? '')
  const [corps, setCorps] = useState(m?.body ?? '')
  const [cat, setCat] = useState(m?.category ?? 'complaint')
  const sauver = useAction('support_template_save', onClose)
  const supprimer = useAction('support_template_delete', onClose)

  const envoyer = (e: FormEvent) => {
    e.preventDefault()
    sauver.mutate({ p_id: m?.id ?? null, p_title: titre, p_body: corps, p_category: cat })
  }
  return (
    <Panneau titre={m ? 'Modifier le modèle' : 'Nouveau modèle'} onClose={onClose}>
      <form className="space-y-2" onSubmit={envoyer}>
        <input className="input" placeholder="Titre" value={titre} onChange={(e) => setTitre(e.target.value)} required />
        <select className="input" value={cat} onChange={(e) => setCat(e.target.value)} aria-label="Catégorie">
          {CATEGORIES.map((c) => <option key={c}>{c}</option>)}
        </select>
        <textarea className="input" rows={6} placeholder="Texte de la réponse" value={corps} onChange={(e) => setCorps(e.target.value)} required />
        <button className="btn btn-primary" disabled={sauver.isPending}>Enregistrer</button>
        {sauver.isError && <p role="alert" className="text-sm text-red-600">{messageErreur(sauver.error)}</p>}
      </form>
      {m && (
        <>
          <button className="btn btn-danger" disabled={supprimer.isPending}
            onClick={() => { if (confirm('Supprimer ce modèle ?')) supprimer.mutate({ p_id: m.id }) }}>Supprimer</button>
          {supprimer.isError && <p role="alert" className="text-sm text-red-600">{messageErreur(supprimer.error)}</p>}
        </>
      )}
    </Panneau>
  )
}
