import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { messageErreur } from '../lib/erreurs'
import { ROLES, definirRole, libelleRole, messageCallable } from '../lib/roles'
import { Badge, Empty, ErrorBox, Loading, fmtDate } from '../components/States'

interface Compte {
  id: string
  display_name: string | null
  email: string | null
  admin_role: string | null
  is_admin: boolean
  created_at: string
}

/** Les comptes se lisent par `profils_admin_page` (fonction serveur, droit nommé) : la table `users` n'expose plus ses colonnes privées. */
async function chercher(recherche: string | null, filtre: 'admins' | 'tous'): Promise<Compte[]> {
  const { data, error } = await supabase.rpc('profils_admin_page', {
    p_recherche: recherche, p_filtre: filtre, p_decalage: 0, p_limite: filtre === 'admins' ? 100 : 20,
  })
  if (error) throw error
  return (data ?? []) as Compte[]
}

export default function Administrateurs() {
  const qc = useQueryClient()
  const admins = useQuery({ queryKey: ['administrateurs'], queryFn: () => chercher(null, 'admins') })
  const [saisie, setSaisie] = useState('')
  const [terme, setTerme] = useState('')
  const [role, setRole] = useState('')

  const trouves = useQuery({
    queryKey: ['administrateurs-recherche', terme],
    enabled: terme.length >= 3,
    queryFn: () => chercher(terme, 'tous'),
  })

  const attribuer = useMutation({
    mutationFn: (a: { uid: string; adminRole: string }) => definirRole(a.uid, a.adminRole),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['administrateurs'] })
      await qc.invalidateQueries({ queryKey: ['administrateurs-recherche'] })
      await qc.invalidateQueries({ queryKey: ['roles-matrice'] })
    },
  })

  const rechercher = (e: FormEvent) => {
    e.preventDefault()
    setTerme(saisie.trim())
  }

  function donner(c: Compte) {
    if (!role) return
    const nom = c.display_name ?? c.id
    if (confirm(`Donner le rôle « ${libelleRole(role)} » à ${nom} ? Le changement s'inscrit au journal d'audit.`)) {
      attribuer.mutate({ uid: c.id, adminRole: role })
    }
  }

  function retirer(c: Compte) {
    const nom = c.display_name ?? c.id
    if (confirm(`Retirer tous les droits d'administration à ${nom} ?`)) {
      attribuer.mutate({ uid: c.id, adminRole: 'none' })
    }
  }

  return (
    <section className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Administrateurs</h1>
        <p className="text-sm text-slate-500">
          Attribuer, changer ou retirer un rôle d'administration. Seul un super-administrateur le peut ; le serveur
          revérifie, refuse de modifier votre propre compte et de retirer le dernier super-administrateur.
        </p>
      </div>

      {attribuer.isError && <p role="alert" className="card border-red-200 bg-red-50 text-sm text-red-800">{messageCallable(attribuer.error)}</p>}
      {attribuer.isSuccess && <p role="status" className="card border-green-200 bg-green-50 text-sm text-green-800">Rôle enregistré. Il prend effet à la prochaine ouverture de session de la personne.</p>}

      <div className="card space-y-3">
        <h2 className="font-semibold">Ajouter un administrateur</h2>
        <p className="text-sm text-slate-500">
          La personne doit déjà avoir un compte : elle se connecte une première fois à l'application, puis vous la
          retrouvez ici par pseudo ou e-mail (3 caractères au moins).
        </p>
        <form onSubmit={rechercher} className="flex flex-wrap gap-2">
          <input className="input max-w-xs" aria-label="Rechercher un compte" placeholder="Pseudo ou e-mail"
            value={saisie} onChange={(e) => setSaisie(e.target.value)} />
          <button className="btn btn-primary" disabled={saisie.trim().length < 3}>Rechercher</button>
        </form>
        <label className="block text-sm">Rôle à donner
          <select className="input mt-1 max-w-xs" value={role} onChange={(e) => setRole(e.target.value)}>
            <option value="">Choisir…</option>
            {ROLES.map((r) => <option key={r.id} value={r.id}>{r.label}{r.limite ? ' (rôle limité)' : ''}</option>)}
          </select>
        </label>
        {ROLES.find((r) => r.id === role)?.limite && (
          <p className="text-xs text-slate-500">
            Un rôle limité n'agit que par ses droits nommés ; il exige la migration des rôles limités et la fonction
            <code> setAdminRole</code> déployées. Sinon le serveur refuse avec un message.
          </p>
        )}
        {trouves.isLoading && <Loading />}
        {trouves.isError && <ErrorBox error={trouves.error} onRetry={() => void trouves.refetch()} />}
        {trouves.isSuccess && trouves.data.length === 0 && <Empty>Aucun compte ne correspond.</Empty>}
        <ul className="divide-y divide-slate-100">
          {trouves.data?.map((c) => (
            <li key={c.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
              <span>
                <span className="font-medium">{c.display_name ?? '—'}</span>{' '}
                <span className="text-slate-500">{c.email ?? ''}</span>{' '}
                {c.is_admin ? <Badge tone="amber">{libelleRole(c.admin_role)}</Badge> : null}
              </span>
              <button className="btn btn-primary" disabled={!role || attribuer.isPending} onClick={() => donner(c)}>
                {c.is_admin ? 'Changer le rôle' : 'Donner ce rôle'}
              </button>
            </li>
          ))}
        </ul>
      </div>

      <div>
        <h2 className="mb-2 text-lg font-semibold">Administrateurs actuels</h2>
        {admins.isLoading && <Loading />}
        {admins.isError && <ErrorBox error={admins.error} onRetry={() => void admins.refetch()} />}
        {admins.isSuccess && admins.data.length === 0 && <Empty>Aucun administrateur.</Empty>}
        {admins.isSuccess && admins.data.length > 0 && (
          <div className="card overflow-x-auto p-0">
            <table className="w-full">
              <thead className="border-b border-slate-200 bg-slate-50">
                <tr>
                  <th className="th">Compte</th>
                  <th className="th">Rôle</th>
                  <th className="th">Inscrit le</th>
                  <th className="th"><span className="sr-only">Action</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {admins.data.map((c) => (
                  <tr key={c.id}>
                    <td className="td"><span className="font-medium">{c.display_name ?? '—'}</span> <span className="text-slate-500">{c.email ?? ''}</span></td>
                    <td className="td">
                      {c.admin_role ? <Badge tone="blue">{libelleRole(c.admin_role)}</Badge> : <Badge tone="red">Admin sans rôle</Badge>}
                    </td>
                    <td className="td">{fmtDate(c.created_at)}</td>
                    <td className="td text-right">
                      <button className="btn btn-danger" disabled={attribuer.isPending} onClick={() => retirer(c)}>Retirer</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {admins.isError && <p className="mt-2 text-xs text-slate-500">{messageErreur(admins.error)}</p>}
      </div>
    </section>
  )
}
