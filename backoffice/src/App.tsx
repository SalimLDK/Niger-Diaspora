import { NavLink, Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { Building2, CalendarDays, UsersRound, Settings, Globe2, BarChart3, KeyRound, Megaphone, Landmark, Gauge, History, Flag, LifeBuoy, LogOut, ShieldAlert, UserCheck, Users } from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { useInactivite } from './auth/useInactivite'
import { appliquerTheme, themeSombreActif } from './lib/theme'
import RechercheGlobale from './components/RechercheGlobale'
import { useAuth } from './auth/AuthProvider'
import { PERM, type PermKey } from './lib/permissions'
import Login from './pages/Login'
import { Denied, Loading } from './components/States'
import { lazy, Suspense, type ComponentType } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from './lib/supabase'

const Dashboard = lazy(() => import('./pages/Dashboard'))
const Members = lazy(() => import('./pages/Members'))
const Reports = lazy(() => import('./pages/Reports'))
const Audit = lazy(() => import('./pages/Audit'))
const Stats = lazy(() => import('./pages/Stats'))
const Reglages = lazy(() => import('./pages/Reglages'))
const Roles = lazy(() => import('./pages/Roles'))
const Modeles = lazy(() => import('./pages/Modeles'))
const nomme = (m: Promise<Record<string, unknown>>, n: string) =>
  m.then((x) => ({ default: x[n] as ComponentType }))
const Campagnes = lazy(() => nomme(import('./pages/Validation'), 'Campagnes'))
const Demarches = lazy(() => nomme(import('./pages/Validation'), 'Demarches'))
const Ambassades = lazy(() => nomme(import('./pages/Modules'), 'Ambassades'))
const Annuaire = lazy(() => nomme(import('./pages/Modules'), 'Annuaire'))
const Confidentialite = lazy(() => nomme(import('./pages/Modules'), 'Confidentialite'))
const Evenements = lazy(() => nomme(import('./pages/Modules'), 'Evenements'))
const Groupes = lazy(() => nomme(import('./pages/Modules'), 'Groupes'))
const Incidents = lazy(() => nomme(import('./pages/Modules'), 'Incidents'))
const Support = lazy(() => nomme(import('./pages/Modules'), 'Support'))

const NAV: { to: string; label: string; perm: PermKey; icon: ReactNode }[] = [
  { to: '/', label: 'Vue générale', perm: PERM.dashboard, icon: <Gauge size={18} /> },
  { to: '/statistiques', label: 'Statistiques', perm: PERM.stats, icon: <BarChart3 size={18} /> },
  { to: '/membres', label: 'Membres', perm: PERM.members, icon: <Users size={18} /> },
  { to: '/signalements', label: 'Signalements', perm: PERM.reports, icon: <Flag size={18} /> },
  { to: '/groupes', label: 'Groupes', perm: PERM.groups, icon: <UsersRound size={18} /> },
  { to: '/campagnes', label: 'Campagnes', perm: PERM.campaigns, icon: <Megaphone size={18} /> },
  { to: '/demarches', label: 'Démarches', perm: PERM.demarches, icon: <Landmark size={18} /> },
  { to: '/modeles', label: 'Modèles de réponse', perm: PERM.templates, icon: <LifeBuoy size={18} /> },
  { to: '/support', label: 'Support', perm: PERM.support, icon: <LifeBuoy size={18} /> },
  { to: '/evenements', label: 'Événements', perm: PERM.events, icon: <CalendarDays size={18} /> },
  { to: '/ambassades', label: 'Ambassades', perm: PERM.embassies, icon: <Globe2 size={18} /> },
  { to: '/annuaire', label: 'Annuaire', perm: PERM.directory, icon: <Building2 size={18} /> },
  { to: '/confidentialite', label: 'Confidentialité', perm: PERM.privacy, icon: <UserCheck size={18} /> },
  { to: '/incidents', label: 'Incidents', perm: PERM.incidents, icon: <ShieldAlert size={18} /> },
  { to: '/roles', label: 'Rôles et permissions', perm: PERM.roles, icon: <KeyRound size={18} /> },
  { to: '/reglages', label: 'Réglages', perm: PERM.settings, icon: <Settings size={18} /> },
  { to: '/audit', label: "Journal d'audit", perm: PERM.audit, icon: <History size={18} /> },
]

function Shell() {
  const { etat, peut, deconnexion } = useAuth()
  const [reduit, setReduit] = useState(() => { try { return localStorage.getItem('nav-reduit') === '1' } catch { return false } })
  const basculer = () => setReduit((v) => { try { localStorage.setItem('nav-reduit', v ? '0' : '1') } catch { /* ignoré */ } return !v })
  const [sombre, setSombre] = useState(themeSombreActif())
  const alertes = useQuery({
    queryKey: ['dashboard-tasks'],
    refetchInterval: 60_000,
    queryFn: async () => {
      const { data, error } = await supabase.rpc('admin_dashboard_tasks')
      if (error) throw error
      return data as unknown
    },
  })
  const items = ((alertes.data as { items?: { count: number; urgent: number }[] } | null)?.items ?? [])
  const urgents = items.reduce((a, t) => a + (t.urgent ?? 0), 0)
  useEffect(() => { document.title = urgents > 0 ? `(${urgents}) Diaspo Niger — Console` : 'Diaspo Niger — Console' }, [urgents])
  useInactivite(15, () => { void deconnexion() })
  if (etat.k !== 'pret') return null
  return (
    <>
    <a href="#contenu" className="sr-only focus:not-sr-only focus:absolute focus:left-2 focus:top-2 focus:z-20 focus:rounded focus:bg-white focus:p-2">Aller au contenu</a>
    <div className={`grid min-h-screen grid-cols-1 ${reduit ? 'md:grid-cols-[4rem_1fr]' : 'md:grid-cols-[15rem_1fr]'}`}>
      <aside className="bg-ink p-4 text-slate-200">
        <div className="mb-6 flex items-center justify-between">
          {!reduit && <p className="text-lg font-semibold text-white">Diaspo Niger</p>}
          <button className="hidden rounded p-1 hover:bg-white/10 md:block" onClick={basculer} aria-label="Réduire ou étendre le menu">{reduit ? '»' : '«'}</button>
        </div>
        <nav aria-label="Navigation principale" className="flex gap-1 md:flex-col">
          {NAV.filter((n) => peut(n.perm)).map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end={n.to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-2 rounded-md px-3 py-2 text-sm ${isActive ? 'bg-brand text-white' : 'hover:bg-white/10'}`
              }
            >
              <span title={n.label}>{n.icon}</span>
              {!reduit && n.label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="flex min-w-0 flex-col">
        <header className="flex flex-wrap items-center justify-end gap-3 border-b border-slate-200 bg-white px-4 py-2 text-sm">
          {urgents > 0 && (
            <NavLink to="/signalements" className="rounded-full bg-red-100 px-3 py-1 text-xs font-medium text-red-800" role="status">
              {urgents} urgent{urgents > 1 ? 's' : ''}
            </NavLink>
          )}
          <RechercheGlobale />
          <button className="btn btn-ghost" aria-pressed={sombre} onClick={() => { appliquerTheme(!sombre); setSombre(!sombre) }}>{sombre ? 'Thème clair' : 'Thème sombre'}</button>
          <span className="text-slate-600">{etat.email}</span>
          <button className="btn btn-ghost" onClick={() => void deconnexion()}>
            <LogOut size={16} /> Déconnexion
          </button>
        </header>
        <main id="contenu" tabIndex={-1} className="min-w-0 flex-1 p-4 md:p-6">
          <Suspense fallback={<Loading />}>
            <Outlet />
          </Suspense>
        </main>
      </div>
    </div>
    </>
  )
}

function Garde({ perm, children }: { perm: PermKey; children: ReactNode }) {
  const { peut } = useAuth()
  return peut(perm) ? <>{children}</> : <Denied />
}

export default function App() {
  const { etat } = useAuth()
  if (etat.k === 'chargement') return <p className="p-8 text-center text-slate-500">Chargement…</p>
  if (etat.k !== 'pret') return <Login />
  return (
    <Routes>
      <Route element={<Shell />}>
        <Route path="/" element={<Garde perm={PERM.dashboard}><Dashboard /></Garde>} />
        <Route path="/statistiques" element={<Garde perm={PERM.stats}><Stats /></Garde>} />
        <Route path="/reglages" element={<Garde perm={PERM.settings}><Reglages /></Garde>} />
        <Route path="/roles" element={<Garde perm={PERM.roles}><Roles /></Garde>} />
        <Route path="/membres" element={<Garde perm={PERM.members}><Members /></Garde>} />
        <Route path="/signalements" element={<Garde perm={PERM.reports}><Reports /></Garde>} />
        <Route path="/audit" element={<Garde perm={PERM.audit}><Audit /></Garde>} />
        <Route path="/groupes" element={<Garde perm={PERM.groups}><Groupes /></Garde>} />
        <Route path="/campagnes" element={<Garde perm={PERM.campaigns}><Campagnes /></Garde>} />
        <Route path="/demarches" element={<Garde perm={PERM.demarches}><Demarches /></Garde>} />
        <Route path="/modeles" element={<Garde perm={PERM.templates}><Modeles /></Garde>} />
        <Route path="/support" element={<Garde perm={PERM.support}><Support /></Garde>} />
        <Route path="/evenements" element={<Garde perm={PERM.events}><Evenements /></Garde>} />
        <Route path="/ambassades" element={<Garde perm={PERM.embassies}><Ambassades /></Garde>} />
        <Route path="/annuaire" element={<Garde perm={PERM.directory}><Annuaire /></Garde>} />
        <Route path="/confidentialite" element={<Garde perm={PERM.privacy}><Confidentialite /></Garde>} />
        <Route path="/incidents" element={<Garde perm={PERM.incidents}><Incidents /></Garde>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
