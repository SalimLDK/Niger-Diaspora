import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import ListeServeur from '../components/ListeServeur'
import { PanneauFiche, PanneauIncident, PanneauPoste } from '../components/PanneauxGestion'
import { PanneauDemande, PanneauEvenement, PanneauTicket } from '../components/Panneaux'
import { Badge, fmtDate } from '../components/States'

const oui = (b: boolean | null | undefined) => (b ? <Badge tone="green">Oui</Badge> : <Badge>Non</Badge>)

interface Ticket { id: string; subject: string; status: string; priority: string | null; category: string | null; assigned_to: string | null; created_at: string; updated_at: string }
export function Support() {
  const [sel, setSel] = useState<Ticket | null>(null)
  /** Tickets dont un délai cible est dépassé (réponse ou résolution), calculé par le serveur. */
  const sla = useQuery({
    queryKey: ['detail', 'sla'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc('support_sla_status')
      if (error) throw error
      const retard = new Set<string>()
      for (const r of (data ?? []) as { ticket_id: string; first_response_late: boolean | null; resolution_late: boolean | null }[]) {
        if (r.first_response_late || r.resolution_late) retard.add(r.ticket_id)
      }
      return retard
    },
  })
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <ListeServeur<Ticket>
    titre="Support"
    aide="Tickets des membres, du plus récemment mis à jour au plus ancien. Lecture seule."
    table="support_tickets"
    rechercheCol="subject"
    select="id,subject,status,priority,category,assigned_to,created_at,updated_at"
    tri="updated_at"
    statuts={[
      { valeur: 'open', libelle: 'Ouvert' }, { valeur: 'in_progress', libelle: 'En cours' },
      { valeur: 'resolved', libelle: 'Résolu' }, { valeur: 'closed', libelle: 'Fermé' },
    ]}
    rowKey={(r) => r.id}
    colonnes={[
      { titre: 'Sujet', cell: (r) => <span className="font-medium">{r.subject}</span> },
      { titre: 'Catégorie', cell: (r) => r.category ?? '—' },
      { titre: 'Priorité', cell: (r) => r.priority ?? '—' },
      { titre: 'Statut', cell: (r) => <Badge tone="blue">{r.status}</Badge> },
      { titre: 'Assigné', cell: (r) => r.assigned_to ? 'Oui' : 'Non' },
      { titre: 'Délai', cell: (r) => sla.isError ? '?' : sla.data?.has(r.id) ? <Badge tone="red">En retard</Badge> : '—' },
      { titre: 'Mis à jour', tri: 'updated_at', cell: (r) => fmtDate(r.updated_at) },
    ]}
        onSelect={setSel}
        selectedKey={sel?.id}
      />
      {sel && <PanneauTicket key={sel.id} id={sel.id} onClose={() => setSel(null)} />}
    </div>
  )
}

interface Evt { id: string; title: string; status: string; city: string | null; country_code: string | null; starts_at: string; attendee_count: number | null; is_online: boolean | null }
export function Evenements() {
  const [sel, setSel] = useState<Evt | null>(null)
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <ListeServeur<Evt>
    titre="Événements"
    aide="Tous les événements, du plus récent au plus ancien. Lecture seule."
    table="events"
    rechercheCol="title"
    select="id,title,status,city,country_code,starts_at,attendee_count,is_online"
    tri="starts_at"
    statuts={[
      { valeur: 'draft', libelle: 'Brouillon' }, { valeur: 'upcoming', libelle: 'À venir' },
      { valeur: 'ongoing', libelle: 'En cours' }, { valeur: 'ended', libelle: 'Terminé' },
      { valeur: 'cancelled', libelle: 'Annulé' },
    ]}
    rowKey={(r) => r.id}
    colonnes={[
      { titre: 'Titre', cell: (r) => <span className="font-medium">{r.title}</span> },
      { titre: 'Début', tri: 'starts_at', cell: (r) => fmtDate(r.starts_at) },
      { titre: 'Lieu', cell: (r) => r.is_online ? 'En ligne' : ([r.city, r.country_code].filter(Boolean).join(', ') || '—') },
      { titre: 'Inscrits', cell: (r) => r.attendee_count ?? 0 },
      { titre: 'Statut', cell: (r) => <Badge tone={r.status === 'cancelled' ? 'red' : 'blue'}>{r.status}</Badge> },
    ]}
        onSelect={setSel}
        selectedKey={sel?.id}
      />
      {sel && <PanneauEvenement key={sel.id} id={sel.id} titre={sel.title} statut={sel.status} onClose={() => setSel(null)} />}
    </div>
  )
}

interface Biz { id: string; name: string; category: string | null; city: string | null; country_code: string | null; is_verified: boolean; is_active: boolean; created_at: string }
export function Annuaire() {
  const [sel, setSel] = useState<Biz | null>(null)
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <ListeServeur<Biz>
    titre="Annuaire — commerces et services"
    aide="Fiches de l'annuaire, des plus récentes aux plus anciennes. Lecture seule."
    table="businesses"
    rechercheCol="name"
    select="id,name,category,city,country_code,is_verified,is_active,created_at"
    tri="created_at"
    rowKey={(r) => r.id}
    colonnes={[
      { titre: 'Nom', tri: 'name_lower', cell: (r) => <span className="font-medium">{r.name || '—'}</span> },
      { titre: 'Catégorie', cell: (r) => r.category ?? '—' },
      { titre: 'Lieu', cell: (r) => [r.city, r.country_code].filter(Boolean).join(', ') || '—' },
      { titre: 'Vérifiée', cell: (r) => oui(r.is_verified) },
      { titre: 'Active', cell: (r) => oui(r.is_active) },
      { titre: 'Créée le', cell: (r) => fmtDate(r.created_at) },
    ]}
        onSelect={setSel}
        selectedKey={sel?.id}
      />
      {sel && <PanneauFiche key={sel.id} f={sel} onClose={() => setSel(null)} />}
    </div>
  )
}

interface Demande { id: string; kind: string; status: string; due_at: string | null; identity_verified_at: string | null; assigned_to: string | null; created_at: string }
export function Confidentialite() {
  const [sel, setSel] = useState<Demande | null>(null)
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <ListeServeur<Demande>
    titre="Confidentialité — demandes de données"
    aide="Accès, rectification, suppression. L'échéance de 30 jours est interne. Lecture seule."
    table="privacy_requests"
    select="id,kind,status,due_at,identity_verified_at,assigned_to,created_at"
    tri="created_at"
    statuts={[
      { valeur: 'received', libelle: 'Reçue' }, { valeur: 'identity_verified', libelle: 'Identité vérifiée' },
      { valeur: 'in_progress', libelle: 'En cours' },
    ]}
    rowKey={(r) => r.id}
    colonnes={[
      { titre: 'Type', cell: (r) => r.kind },
      { titre: 'Statut', cell: (r) => <Badge tone="blue">{r.status}</Badge> },
      { titre: 'Identité vérifiée', cell: (r) => oui(!!r.identity_verified_at) },
      { titre: 'Échéance', cell: (r) => fmtDate(r.due_at) },
      { titre: 'Prise en charge', cell: (r) => r.assigned_to ? 'Oui' : 'Non' },
      { titre: 'Reçue le', cell: (r) => fmtDate(r.created_at) },
    ]}
        onSelect={setSel}
        selectedKey={sel?.id}
      />
      {sel && <PanneauDemande key={sel.id} id={sel.id} statut={sel.status} onClose={() => setSel(null)} />}
    </div>
  )
}

interface Incident { id: string; title: string; severity: string; status: string; detected_at: string; resolved_at: string | null }
export function Incidents() {
  const [sel, setSel] = useState<Incident | null>(null)
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <ListeServeur<Incident>
    titre="Sécurité — incidents"
    aide="Incidents de sécurité enregistrés. Lecture seule."
    table="security_incidents"
    select="id,title,severity,status,detected_at,resolved_at"
    tri="detected_at"
    rowKey={(r) => r.id}
    colonnes={[
      { titre: 'Titre', cell: (r) => <span className="font-medium">{r.title}</span> },
      { titre: 'Gravité', cell: (r) => <Badge tone={r.severity === 'high' || r.severity === 'critical' ? 'red' : 'amber'}>{r.severity}</Badge> },
      { titre: 'Statut', cell: (r) => r.status },
      { titre: 'Détecté le', cell: (r) => fmtDate(r.detected_at) },
      { titre: 'Résolu le', cell: (r) => fmtDate(r.resolved_at) },
    ]}
        onSelect={setSel}
        selectedKey={sel?.id}
      />
      {sel && <PanneauIncident key={sel.id} i={sel} onClose={() => setSel(null)} />}
    </div>
  )
}

interface Groupe { id: string; name: string; category: string | null; country_code: string | null; is_private: boolean; member_count: number; created_at: string }
export const Groupes = () => (
  <ListeServeur<Groupe>
    titre="Groupes"
    aide="Groupes de la communauté (nom, visibilité, effectif). Le contenu des échanges n'est jamais affiché. Lecture seule."
    table="groups"
    rechercheCol="name"
    select="id,name,category,country_code,is_private,member_count,created_at"
    tri="member_count"
    rowKey={(r) => r.id}
    colonnes={[
      { titre: 'Nom', cell: (r) => <span className="font-medium">{r.name}</span> },
      { titre: 'Catégorie', cell: (r) => r.category ?? '—' },
      { titre: 'Pays', cell: (r) => r.country_code ?? '—' },
      { titre: 'Visibilité', cell: (r) => r.is_private ? <Badge tone="amber">Privé</Badge> : <Badge tone="green">Public</Badge> },
      { titre: 'Membres', tri: 'member_count', cell: (r) => r.member_count },
      { titre: 'Créé le', cell: (r) => fmtDate(r.created_at) },
    ]}
  />
)

interface Poste { id: string; name: string; type: string | null; country: string | null; city: string | null; is_verified: boolean; is_suspended: boolean | null; source_url: string | null }
export function Ambassades() {
  const [sel, setSel] = useState<Poste | null>(null)
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <ListeServeur<Poste>
        titre="Ambassades et consulats"
        aide="Fiches des postes diplomatiques. Une source officielle est obligatoire avant vérification."
        table="embassies"
        rechercheCol="name"
        select="id,name,type,country,city,is_verified,is_suspended,source_url"
        tri="name"
        ascendant
        rowKey={(r) => r.id}
        colonnes={[
          { titre: 'Nom', tri: 'name', cell: (r) => <span className="font-medium">{r.name}</span> },
          { titre: 'Type', cell: (r) => r.type ?? '—' },
          { titre: 'Lieu', cell: (r) => [r.city, r.country].filter(Boolean).join(', ') || '—' },
          { titre: 'Vérifié', cell: (r) => (r.is_verified ? <Badge tone="green">Oui</Badge> : <Badge>Non</Badge>) },
          { titre: 'Suspendu', cell: (r) => (r.is_suspended ? <Badge tone="red">Oui</Badge> : <Badge>Non</Badge>) },
        ]}
        onSelect={setSel}
        selectedKey={sel?.id}
      />
      {sel && <PanneauPoste key={sel.id} p={sel} onClose={() => setSel(null)} />}
    </div>
  )
}
