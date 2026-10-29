import type { ReactNode } from 'react'
import { messageErreur } from '../lib/erreurs'

export const Loading = () => (
  <p role="status" className="py-8 text-center text-sm text-slate-500">
    Chargement…
  </p>
)

export const Empty = ({ children }: { children: ReactNode }) => (
  <p className="py-8 text-center text-sm text-slate-500">{children}</p>
)

export const Denied = () => (
  <div role="alert" className="card mx-auto max-w-md text-center">
    <h2 className="font-semibold">Accès refusé</h2>
    <p className="mt-1 text-sm text-slate-600">Vous n'avez pas la permission de consulter cette page.</p>
  </div>
)

/** Une erreur n'est jamais présentée comme « 0 résultat ». */
export function ErrorBox({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  return (
    <div role="alert" className="card border-red-200 bg-red-50 text-sm text-red-800">
      {messageErreur(error)}
      {onRetry && (
        <button className="btn btn-ghost ml-3" onClick={onRetry}>
          Réessayer
        </button>
      )}
    </div>
  )
}

export function Badge({ children, tone = 'slate' }: { children: ReactNode; tone?: 'slate' | 'green' | 'red' | 'blue' | 'amber' }) {
  const t = {
    slate: 'bg-slate-100 text-slate-700',
    green: 'bg-green-100 text-green-800',
    red: 'bg-red-100 text-red-800',
    blue: 'bg-blue-100 text-blue-800',
    amber: 'bg-yellow-100 text-yellow-800',
  }[tone]
  return <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${t}`}>{children}</span>
}

export const fmtDate = (s: string | null | undefined) =>
  s ? new Date(s).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '—'
