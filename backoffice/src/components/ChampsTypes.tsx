import { majChemin, type Section } from '../lib/reglages'

type Valeur = unknown

/** Éditeur typé : booléen → case, nombre → champ numérique, texte → champ texte, objet → sous-groupe, reste → JSON. */
export default function ChampsTypes({ valeur, onChange, chemin = [] }: {
  valeur: Section; onChange: (v: Section) => void; chemin?: string[]
}) {
  const set = (c: string[], v: Valeur) => onChange(majChemin(valeur, c, v))
  return (
    <div className="space-y-2">
      {Object.entries(valeur).map(([k, v]) => {
        const c = [...chemin, k]
        const id = `champ-${c.join('.')}`
        if (typeof v === 'boolean') {
          return (
            <label key={k} className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={v} onChange={(e) => set([k], e.target.checked)} />
              {k}
            </label>
          )
        }
        if (typeof v === 'number') {
          return (
            <label key={k} htmlFor={id} className="block text-sm">
              {k}
              <input id={id} className="input mt-1 max-w-xs" type="number" value={v}
                onChange={(e) => set([k], e.target.value === '' ? 0 : Number(e.target.value))} />
            </label>
          )
        }
        if (typeof v === 'string') {
          return (
            <label key={k} htmlFor={id} className="block text-sm">
              {k}
              <input id={id} className="input mt-1" value={v} onChange={(e) => set([k], e.target.value)} />
            </label>
          )
        }
        if (v && typeof v === 'object' && !Array.isArray(v)) {
          return (
            <fieldset key={k} className="rounded border border-slate-200 p-2">
              <legend className="px-1 text-xs font-semibold text-slate-500">{k}</legend>
              <ChampsTypes valeur={v as Section} chemin={[]} onChange={(sub) => set([k], sub)} />
            </fieldset>
          )
        }
        return (
          <label key={k} htmlFor={id} className="block text-sm">
            {k} (JSON)
            <textarea id={id} className="input mt-1 font-mono text-xs" rows={3} spellCheck={false}
              defaultValue={JSON.stringify(v)}
              onBlur={(e) => { try { set([k], JSON.parse(e.target.value)) } catch { /* valeur conservée : JSON invalide */ } }} />
          </label>
        )
      })}
    </div>
  )
}
