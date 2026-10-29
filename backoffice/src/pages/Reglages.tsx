import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { analyserSection, ecrireSection, lireHistorique, lireReglages, type Entree } from '../lib/reglages'
import { Badge, Empty, ErrorBox, Loading, fmtDate } from '../components/States'

const json = (v: unknown) => JSON.stringify(v, null, 2)

/** Erreur Firestore lisible : un refus de règle n'est jamais présenté comme un succès. */
function lisible(e: unknown): string {
  const c = (e as { code?: string; message?: string })
  if (c.code === 'permission-denied') return "Refusé par les règles Firestore : seul un super-administrateur peut modifier les réglages, avec une entrée d'historique."
  return c.message ?? 'Erreur inattendue.'
}

export default function Reglages() {
  const qc = useQueryClient()
  const reglages = useQuery({ queryKey: ['reglages'], queryFn: lireReglages })
  const histo = useQuery({ queryKey: ['reglages-histo'], queryFn: lireHistorique })
  const [section, setSection] = useState('')
  const [texte, setTexte] = useState('')
  const [raison, setRaison] = useState('')
  const [erreurLocale, setErreurLocale] = useState<string | null>(null)

  const ecrire = useMutation({
    mutationFn: async (a: { section: string; valeur: Record<string, unknown>; raison: string; kind?: 'update' | 'restore'; from?: string }) =>
      ecrireSection(a.section, a.valeur, a.raison, a.kind, a.from),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['reglages'] })
      await qc.invalidateQueries({ queryKey: ['reglages-histo'] })
      setRaison('')
    },
  })

  function choisir(s: string) {
    setSection(s)
    setErreurLocale(null)
    setTexte(s && reglages.data?.[s] ? json(reglages.data[s]) : '')
  }

  function enregistrer() {
    const r = analyserSection(texte)
    if (!r.ok) return setErreurLocale(r.erreur)
    setErreurLocale(null)
    if (confirm(`Enregistrer la section « ${section} » ? L'ancienne valeur sera conservée dans l'historique.`)) {
      ecrire.mutate({ section, valeur: r.valeur, raison })
    }
  }

  function restaurer(e: Entree) {
    if (!e.before) return
    const motif = prompt('Motif du retour arrière :')
    if (!motif?.trim()) return
    ecrire.mutate({ section: e.section, valeur: e.before, raison: motif, kind: 'restore', from: e.id })
  }

  return (
    <section className="space-y-4">
      <h1 className="text-xl font-semibold">Réglages</h1>
      <p className="text-sm text-slate-500">
        Réglages globaux de l'application. Chaque changement écrit son entrée d'historique dans la même transaction ;
        l'écriture est réservée au super-administrateur par les règles Firestore.
      </p>
      {reglages.isLoading && <Loading />}
      {reglages.isError && <ErrorBox error={{ message: lisible(reglages.error) }} onRetry={() => void reglages.refetch()} />}
      {reglages.isSuccess && (
        <div className="card space-y-3">
          <label className="block text-sm">
            Section
            <select className="input mt-1 max-w-xs" value={section} onChange={(e) => choisir(e.target.value)}>
              <option value="">Choisir…</option>
              {Object.keys(reglages.data).sort().map((s) => <option key={s}>{s}</option>)}
            </select>
          </label>
          {section && (
            <>
              <textarea className="input font-mono text-xs" rows={14} value={texte} onChange={(e) => setTexte(e.target.value)} aria-label="Contenu de la section (JSON)" spellCheck={false} />
              <input className="input" placeholder="Motif du changement (obligatoire)" value={raison} onChange={(e) => setRaison(e.target.value)} />
              <button className="btn btn-primary" disabled={!raison.trim() || ecrire.isPending} onClick={enregistrer}>Enregistrer</button>
            </>
          )}
          {erreurLocale && <p role="alert" className="text-sm text-red-600">{erreurLocale}</p>}
          {ecrire.isError && <p role="alert" className="text-sm text-red-600">{lisible(ecrire.error)}</p>}
          {ecrire.isSuccess && <p role="status" className="text-sm text-green-700">Enregistré, historique mis à jour.</p>}
        </div>
      )}

      <h2 className="text-lg font-semibold">Historique</h2>
      {histo.isLoading && <Loading />}
      {histo.isError && <ErrorBox error={{ message: lisible(histo.error) }} />}
      {histo.isSuccess && histo.data.length === 0 && <Empty>Aucun changement enregistré.</Empty>}
      <ul className="space-y-2">
        {histo.data?.map((e) => (
          <li key={e.id} className="card text-sm">
            <p>
              <Badge tone={e.kind === 'restore' ? 'amber' : 'blue'}>{e.kind}</Badge>{' '}
              <span className="font-medium">{e.section}</span> · {fmtDate(e.at?.toISOString())} · par {e.by}
            </p>
            {e.reason && <p className="text-slate-500">Motif : {e.reason}</p>}
            <details className="mt-1">
              <summary className="cursor-pointer text-slate-500">Voir avant / après</summary>
              <div className="mt-1 grid gap-2 md:grid-cols-2">
                <pre className="overflow-auto rounded bg-slate-50 p-2 text-xs">{json(e.before)}</pre>
                <pre className="overflow-auto rounded bg-slate-50 p-2 text-xs">{json(e.after)}</pre>
              </div>
            </details>
            {e.before && <button className="btn btn-ghost mt-2" onClick={() => restaurer(e)}>Revenir à l'ancienne valeur</button>}
          </li>
        ))}
      </ul>
    </section>
  )
}
