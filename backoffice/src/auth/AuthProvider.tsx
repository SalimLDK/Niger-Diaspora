import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import {
  getMultiFactorResolver,
  multiFactor,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  TotpMultiFactorGenerator,
  type MultiFactorResolver,
  type TotpSecret,
  type User,
} from 'firebase/auth'
import { fbAuth } from '../lib/firebase'
import { echangerJeton, supabase } from '../lib/supabase'
import { ALL_PERMS, type PermKey } from '../lib/permissions'

type Etat =
  | { k: 'chargement' }
  | { k: 'deconnecte'; message?: string }
  | { k: 'second_facteur'; resolver: MultiFactorResolver }
  | { k: 'enrolement'; user: User; secret: TotpSecret }
  | { k: 'pret'; email: string; perms: Set<PermKey> }

interface Ctx {
  etat: Etat
  connexion: (email: string, mdp: string) => Promise<void>
  validerCode: (code: string) => Promise<void>
  confirmerEnrolement: (code: string) => Promise<void>
  deconnexion: () => Promise<void>
  peut: (p: PermKey) => boolean
}
const AuthCtx = createContext<Ctx | null>(null)

async function chargerPermissions(): Promise<Set<PermKey>> {
  const res = await Promise.all(
    ALL_PERMS.map(async (p) => {
      const { data, error } = await supabase.rpc('admin_has_permission', { perm: p })
      if (error) throw error
      return data === true ? p : null
    }),
  )
  return new Set(res.filter((p): p is PermKey => p !== null))
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [etat, setEtat] = useState<Etat>({ k: 'chargement' })

  /** Ouvre la console seulement si : second facteur dans le jeton ET au moins un droit admin. */
  const ouvrir = useCallback(async (user: User) => {
    const tok = await user.getIdTokenResult(true)
    const fb = tok.claims.firebase as { sign_in_second_factor?: string } | undefined
    if (multiFactor(user).enrolledFactors.length === 0) {
      const session = await multiFactor(user).getSession()
      const secret = await TotpMultiFactorGenerator.generateSecret(session)
      setEtat({ k: 'enrolement', user, secret })
      return
    }
    if (!fb?.sign_in_second_factor) {
      await signOut(fbAuth)
      setEtat({ k: 'deconnecte', message: 'Reconnectez-vous : le second facteur est obligatoire.' })
      return
    }
    await echangerJeton(tok.token)
    const perms = await chargerPermissions()
    if (perms.size === 0) {
      await signOut(fbAuth)
      await supabase.auth.signOut()
      setEtat({ k: 'deconnecte', message: "Ce compte n'a aucun droit sur la console." })
      return
    }
    setEtat({ k: 'pret', email: user.email ?? '', perms })
  }, [])

  useEffect(() => {
    return onAuthStateChanged(fbAuth, (u) => {
      if (!u) {
        setEtat((e) =>
          e.k === 'second_facteur' || (e.k === 'deconnecte' && e.message) ? e : { k: 'deconnecte' },
        )
        return
      }
      setEtat((e) => (e.k === 'pret' || e.k === 'enrolement' ? e : { k: 'chargement' }))
      ouvrir(u).catch((err: Error) => {
        setEtat({ k: 'deconnecte', message: err.message })
      })
    })
  }, [ouvrir])

  const connexion = useCallback(async (email: string, mdp: string) => {
    try {
      await signInWithEmailAndPassword(fbAuth, email, mdp)
    } catch (e) {
      const code = (e as { code?: string }).code
      if (code === 'auth/multi-factor-auth-required') {
        setEtat({ k: 'second_facteur', resolver: getMultiFactorResolver(fbAuth, e as never) })
        return
      }
      throw new Error('Identifiants invalides.')
    }
  }, [])

  const validerCode = useCallback(
    async (code: string) => {
      if (etat.k !== 'second_facteur') return
      const hint = etat.resolver.hints.find((h) => h.factorId === TotpMultiFactorGenerator.FACTOR_ID)
      if (!hint) throw new Error('Aucun second facteur TOTP enrôlé sur ce compte.')
      const assertion = TotpMultiFactorGenerator.assertionForSignIn(hint.uid, code)
      try {
        await etat.resolver.resolveSignIn(assertion)
      } catch {
        throw new Error('Code invalide ou expiré.')
      }
    },
    [etat],
  )

  const confirmerEnrolement = useCallback(
    async (code: string) => {
      if (etat.k !== 'enrolement') return
      const assertion = TotpMultiFactorGenerator.assertionForEnrollment(etat.secret, code)
      try {
        await multiFactor(etat.user).enroll(assertion, 'Console Diaspo Niger')
      } catch {
        throw new Error('Code invalide ou expiré.')
      }
      await signOut(fbAuth)
      setEtat({ k: 'deconnecte', message: 'Second facteur activé. Reconnectez-vous.' })
    },
    [etat],
  )

  const deconnexion = useCallback(async () => {
    await supabase.auth.signOut()
    await signOut(fbAuth)
    setEtat({ k: 'deconnecte' })
  }, [])

  const peut = useCallback((p: PermKey) => etat.k === 'pret' && etat.perms.has(p), [etat])

  const value = useMemo(
    () => ({ etat, connexion, validerCode, confirmerEnrolement, deconnexion, peut }),
    [etat, connexion, validerCode, confirmerEnrolement, deconnexion, peut],
  )
  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>
}

export function useAuth(): Ctx {
  const c = useContext(AuthCtx)
  if (!c) throw new Error('useAuth hors AuthProvider')
  return c
}
