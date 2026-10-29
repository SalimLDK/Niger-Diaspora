import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { Badge, ErrorBox, Loading } from '../components/States'

interface Perm { key: string; module: string; description: string }
interface Lien { role: string; permission: string }
const ROLES = [
  { id: 'contentMod', label: 'Modérateur contenu' },
  { id: 'businessMod', label: 'Gestionnaire commercial' },
  { id: 'financeMod', label: 'Gestionnaire financier' },
]

/** Matrice rôles × permissions, en lecture seule, avec vos propres droits. Le super-administrateur a tout le catalogue. */
export default function Roles() {
  const q = useQuery({
    queryKey: ['roles-matrice'],
    queryFn: async () => {
      const [p, l] = await Promise.all([
        supabase.from('admin_permissions').select('key,module,description').order('module').order('key'),
        supabase.from('admin_role_permissions').select('role,permission'),
      ])
      if (p.error) throw p.error
      if (l.error) throw l.error
      const perms = (p.data ?? []) as Perm[]
      const moi = new Set<string>()
      await Promise.all(perms.map(async (x) => {
        const { data } = await supabase.rpc('admin_has_permission', { perm: x.key })
        if (data === true) moi.add(x.key)
      }))
      return { perms, liens: (l.data ?? []) as Lien[], moi }
    },
  })

  return (
    <section>
      <h1 className="mb-1 text-xl font-semibold">Rôles et permissions</h1>
      <p className="mb-4 text-sm text-slate-500">
        Catalogue tenu côté serveur. Lecture seule : l'attribution d'un rôle passe par une fonction à double contrôle.
      </p>
      {q.isLoading && <Loading />}
      {q.isError && <ErrorBox error={q.error} onRetry={() => void q.refetch()} />}
      {q.isSuccess && (
        <div className="card overflow-x-auto p-0">
          <table className="w-full">
            <thead className="border-b border-slate-200 bg-slate-50">
              <tr>
                <th className="th">Module</th>
                <th className="th">Permission</th>
                <th className="th">Description</th>
                {ROLES.map((r) => <th key={r.id} className="th">{r.label}</th>)}
                <th className="th">Vous</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {q.data.perms.map((p) => (
                <tr key={p.key}>
                  <td className="td">{p.module}</td>
                  <td className="td font-mono text-xs">{p.key}</td>
                  <td className="td">{p.description}</td>
                  {ROLES.map((r) => (
                    <td key={r.id} className="td text-center">
                      {q.data.liens.some((l) => l.role === r.id && l.permission === p.key) ? '✓' : '·'}
                    </td>
                  ))}
                  <td className="td">{q.data.moi.has(p.key) ? <Badge tone="green">Oui</Badge> : <Badge>Non</Badge>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
