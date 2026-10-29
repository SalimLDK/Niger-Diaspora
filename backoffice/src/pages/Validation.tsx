import { useState } from 'react'
import ListeServeur from '../components/ListeServeur'
import { PanneauCampagne, PanneauDemarche } from '../components/PanneauxValidation'
import NouvelleCampagne from '../components/NouvelleCampagne'
import { Badge, fmtDate } from '../components/States'

interface Camp { id: string; type: string; title: string; body: string; status: string; review_note: string | null; created_at: string; sent_at: string | null }

export function Campagnes() {
  const [sel, setSel] = useState<Camp | null>(null)
  const [nouvelle, setNouvelle] = useState(false)
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <div>
      <button className="btn btn-primary mb-3" onClick={() => { setSel(null); setNouvelle(true) }}>Nouvelle campagne</button>
      <ListeServeur<Camp>
        titre="Campagnes de notification"
        aide="Validation et annulation. Aucune campagne ne part sans approbation d'un autre administrateur."
        table="campaigns"
        select="id,type,title,body,status,review_note,created_at,sent_at"
        tri="created_at"
        statuts={['draft', 'pending_approval', 'approved', 'sending', 'sent', 'rejected', 'cancelled'].map((v) => ({ valeur: v, libelle: v }))}
        rowKey={(r) => r.id}
        colonnes={[
          { titre: 'Titre', cell: (r) => <span className="font-medium">{r.title}</span> },
          { titre: 'Type', cell: (r) => r.type },
          { titre: 'Statut', cell: (r) => <Badge tone={r.status === 'pending_approval' ? 'amber' : 'blue'}>{r.status}</Badge> },
          { titre: 'Créée le', cell: (r) => fmtDate(r.created_at) },
          { titre: 'Envoyée le', cell: (r) => fmtDate(r.sent_at) },
        ]}
        onSelect={(c) => { setNouvelle(false); setSel(c) }}
        selectedKey={sel?.id}
      />
      </div>
      {nouvelle && <NouvelleCampagne onDone={() => setNouvelle(false)} />}
      {sel && !nouvelle && <PanneauCampagne key={sel.id} c={sel} onClose={() => setSel(null)} />}
    </div>
  )
}

interface Dem { id: string; demarche_id: string; status: string; change_reason: string | null; review_note: string | null; submitted_at: string | null; updated_at: string }

export function Demarches() {
  const [sel, setSel] = useState<Dem | null>(null)
  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_24rem]">
      <ListeServeur<Dem>
        titre="Démarches consulaires"
        aide="Versions en brouillon, relecture et publication. Chaque publication exige une relecture."
        table="demarches_brouillons"
        select="id,demarche_id,status,change_reason,review_note,submitted_at,updated_at"
        tri="updated_at"
        statuts={['draft', 'pending', 'approved', 'rejected', 'published'].map((v) => ({ valeur: v, libelle: v }))}
        rowKey={(r) => r.id}
        colonnes={[
          { titre: 'Démarche', cell: (r) => <span className="font-medium">{r.demarche_id}</span> },
          { titre: 'Statut', cell: (r) => <Badge tone={r.status === 'pending' ? 'amber' : 'blue'}>{r.status}</Badge> },
          { titre: 'Motif', cell: (r) => r.change_reason ?? '—' },
          { titre: 'Soumise le', cell: (r) => fmtDate(r.submitted_at) },
          { titre: 'Mise à jour', cell: (r) => fmtDate(r.updated_at) },
        ]}
        onSelect={setSel}
        selectedKey={sel?.id}
      />
      {sel && <PanneauDemarche key={sel.id} d={sel} onClose={() => setSel(null)} />}
    </div>
  )
}
