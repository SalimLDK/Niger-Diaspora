import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { messageErreur } from '../lib/erreurs'
import { masquerEmail } from '../lib/email'
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
interface Trouve {
  id: string
  display_name: string | null
  email_masked: string | null
  created_at: string
  is_admin: boolean
  admin_role: string | null
}
interface Invitation {
  id: string
  invitee_id: string
  invitee_name: string | null
  invitee_email_masked: string | null
  role: string
  status: string
  invited_by_name: string | null
  approved_by_name: string | null
  expires_at: string
  created_at: string
}

const STATUT: Record<string, { label: string; tone: 'slate' | 'green' | 'red' | 'blue' | 'amber' }> = {
  pending_approval: { label: "En attente d'approbation", tone: 'amber' },
  pending: { label: 'Envoyée', tone: 'blue' },
  accepted: { label: 'Acceptée', tone: 'green' },
  declined: { label: 'Refusée', tone: 'red' },
  revoked: { label: 'Révoquée', tone: 'slate' },
  expired: { label: 'Expirée', tone: 'slate' },
}

/** Les administrateurs en place se lisent par `profils_admin_page` (fonction serveur, droit nommé). */
async function listerAdmins(): Promise<Compte[]> {
  const { data, error } = await supabase.rpc('profils_admin_page', { p_recherche: null, p_filtre: 'admins', p_decalage: 0, p_limite: 100 })
  if (error) throw error
  return (data ?? []) as Compte[]
}

export default function Administrateurs() {
  const qc = useQueryClient()
  const admins = useQuery({ queryKey: ['administrateurs'], queryFn: listerAdmins })
  const invitations = useQuery({
    queryKey: ['invitations'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('admin_invitation_list')
      if (error) throw error
      return (data ?? []) as Invitation[]
    },
  })

  const [saisie, setSaisie] = useState('')
  const [terme, setTerme] = useState('')
  const [role, setRole] = useState('')

  const trouves = useQuery({
    queryKey: ['administrateurs-recherche', terme],
    enabled: terme.length >= 3,
    queryFn: async () => {
      const { data, error } = await supabase.rpc('admin_member_search', { p_term: terme })
      if (error) throw error
      return (data ?? []) as Trouve[]
    },
  })

  const rafraichir = async () => {
    await qc.invalidateQueries({ queryKey: ['invitations'] })
    await qc.invalidateQueries({ queryKey: ['administrateurs'] })
    await qc.invalidateQueries({ queryKey: ['roles-matrice'] })
  }

  const inviter = useMutation({
    mutationFn: async (a: { membre: string; role: string }) => {
      const { error } = await supabase.rpc('admin_invitation_create', { p_member_id: a.membre, p_role: a.role })
      if (error) throw error
    },
    onSuccess: rafraichir,
  })
  const approuver = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.rpc('admin_invitation_approve', { p_id: id })
      if (error) throw error
    },
    onSuccess: rafraichir,
  })
  const revoquer = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.rpc('admin_invitation_revoke', { p_id: id })
      if (error) throw error
    },
    onSuccess: rafraichir,
  })
  const retirer = useMutation({ mutationFn: (uid: string) => definirRole(uid, 'none'), onSuccess: rafraichir })

  const rechercher = (e: FormEvent) => {
    e.preventDefault()
    setTerme(saisie.trim())
  }

  function inviterMembre(c: Trouve) {
    if (!role) return
    const nom = c.display_name ?? c.id
    const sup = role === 'superAdmin' ? ' Un second super-administrateur devra approuver cette invitation.' : ''
    if (confirm(`Inviter ${nom} (${c.email_masked ?? 'e-mail non renseigné'}) au rôle « ${libelleRole(role)} » ? Ses droits ne seront activés qu'après son acceptation.${sup}`)) {
      inviter.mutate({ membre: c.id, role })
    }
  }

  const erreurs = [inviter.error, approuver.error, revoquer.error].find(Boolean)

  return (
    <section className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Administrateurs</h1>
        <p className="text-sm text-slate-500">
          Un rôle d'administration s'active <strong>après acceptation</strong> de la personne invitée. Seul un super-administrateur
          invite ; le rôle super-administrateur exige l'approbation d'un second. Tout est inscrit au journal d'audit.
        </p>
      </div>

      {erreurs ? <p role="alert" className="card border-red-200 bg-red-50 text-sm text-red-800">{messageErreur(erreurs)}</p> : null}
      {retirer.isError && <p role="alert" className="card border-red-200 bg-red-50 text-sm text-red-800">{messageCallable(retirer.error)}</p>}
      {inviter.isSuccess && <p role="status" className="card border-green-200 bg-green-50 text-sm text-green-800">Invitation créée. Le membre la verra à sa prochaine connexion à la console (elle expire dans 7 jours).</p>}
      {retirer.isSuccess && <p role="status" className="card border-green-200 bg-green-50 text-sm text-green-800">Droits retirés. Le changement prend effet à la prochaine ouverture de session de la personne.</p>}

      <div className="card space-y-3">
        <h2 className="font-semibold">Inviter un membre</h2>
        <p className="text-sm text-slate-500">
          La personne doit déjà avoir un compte et s'être connectée une première fois à l'application. Recherche par pseudo ou
          début d'adresse e-mail (3 caractères au moins) ; les adresses s'affichent masquées et les recherches sont limitées.
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
        {trouves.isLoading && <Loading />}
        {trouves.isError && <ErrorBox error={trouves.error} onRetry={() => void trouves.refetch()} />}
        {trouves.isSuccess && trouves.data.length === 0 && <Empty>Aucun compte ne correspond.</Empty>}
        <ul className="divide-y divide-slate-100">
          {trouves.data?.map((c) => (
            <li key={c.id} className="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
              <span>
                <span className="font-medium">{c.display_name ?? '—'}</span>{' '}
                <span className="text-slate-500">{c.email_masked ?? ''}</span>{' '}
                <span className="text-slate-400">inscrit le {fmtDate(c.created_at)}</span>{' '}
                {c.is_admin ? <Badge tone="amber">{libelleRole(c.admin_role)}</Badge> : null}
              </span>
              <button className="btn btn-primary" disabled={!role || inviter.isPending} onClick={() => inviterMembre(c)}>Inviter</button>
            </li>
          ))}
        </ul>
      </div>

      <div>
        <h2 className="mb-2 text-lg font-semibold">Invitations</h2>
        {invitations.isLoading && <Loading />}
        {invitations.isError && <ErrorBox error={invitations.error} onRetry={() => void invitations.refetch()} />}
        {invitations.isSuccess && invitations.data.length === 0 && <Empty>Aucune invitation.</Empty>}
        {invitations.isSuccess && invitations.data.length > 0 && (
          <div className="card overflow-x-auto p-0">
            <table className="w-full">
              <thead className="border-b border-slate-200 bg-slate-50">
                <tr>
                  <th className="th">Personne</th><th className="th">Rôle</th><th className="th">État</th>
                  <th className="th">Invitée par</th><th className="th">Expire</th><th className="th"><span className="sr-only">Actions</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {invitations.data.map((i) => {
                  const s = STATUT[i.status] ?? { label: i.status, tone: 'slate' as const }
                  const ouverte = i.status === 'pending' || i.status === 'pending_approval'
                  return (
                    <tr key={i.id}>
                      <td className="td"><span className="font-medium">{i.invitee_name ?? '—'}</span> <span className="text-slate-500">{i.invitee_email_masked ?? ''}</span></td>
                      <td className="td">{libelleRole(i.role)}</td>
                      <td className="td"><Badge tone={s.tone}>{s.label}</Badge></td>
                      <td className="td">{i.invited_by_name ?? '—'}{i.approved_by_name ? <span className="text-slate-500"> · approuvée par {i.approved_by_name}</span> : null}</td>
                      <td className="td">{ouverte ? fmtDate(i.expires_at) : '—'}</td>
                      <td className="td space-x-2 text-right">
                        {i.status === 'pending_approval' && (
                          <button className="btn btn-primary" disabled={approuver.isPending} onClick={() => approuver.mutate(i.id)}>Approuver</button>
                        )}
                        {ouverte && (
                          <button className="btn btn-ghost" disabled={revoquer.isPending}
                            onClick={() => { if (confirm('Révoquer cette invitation ?')) revoquer.mutate(i.id) }}>Révoquer</button>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
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
                  <th className="th">Compte</th><th className="th">Rôle</th><th className="th">Inscrit le</th>
                  <th className="th"><span className="sr-only">Action</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {admins.data.map((c) => (
                  <tr key={c.id}>
                    <td className="td"><span className="font-medium">{c.display_name ?? '—'}</span> <span className="text-slate-500">{masquerEmail(c.email)}</span></td>
                    <td className="td">{c.admin_role ? <Badge tone="blue">{libelleRole(c.admin_role)}</Badge> : <Badge tone="red">Admin sans rôle</Badge>}</td>
                    <td className="td">{fmtDate(c.created_at)}</td>
                    <td className="td text-right">
                      <button className="btn btn-danger" disabled={retirer.isPending}
                        onClick={() => { if (confirm(`Retirer tous les droits d'administration à ${c.display_name ?? c.id} ? Effet immédiat, sans attendre son accord.`)) retirer.mutate(c.id) }}>
                        Retirer
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <p className="mt-2 text-xs text-slate-500">
          Le retrait est immédiat et ne demande pas l'accord de la personne. Le serveur refuse de modifier votre propre compte et de retirer
          le dernier super-administrateur. Pour changer le rôle d'un administrateur en place, invitez-le au nouveau rôle.
        </p>
      </div>
    </section>
  )
}
