import { useEffect, useState, type FormEvent } from 'react'
import QRCode from 'qrcode'
import { ShieldCheck } from 'lucide-react'
import { sendPasswordResetEmail } from 'firebase/auth'
import { fbAuth } from '../lib/firebase'
import { useAuth } from '../auth/AuthProvider'

export default function Login() {
  const { etat, connexion, validerCode, confirmerEnrolement } = useAuth()
  const [email, setEmail] = useState('')
  const [mdp, setMdp] = useState('')
  const [code, setCode] = useState('')
  const [err, setErr] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [qr, setQr] = useState<string | null>(null)
  const [info, setInfo] = useState<string | null>(null)

  async function oublie() {
    setErr(null)
    if (!email) return setErr("Saisissez d'abord votre adresse e-mail.")
    try { await sendPasswordResetEmail(fbAuth, email) } catch { /* réponse volontairement identique */ }
    setInfo("Si ce compte existe, un e-mail de réinitialisation vient d'être envoyé.")
  }

  useEffect(() => {
    if (etat.k === 'enrolement') {
      const url = etat.secret.generateQrCodeUrl(etat.user.email ?? 'admin', 'Diaspo Niger Console')
      QRCode.toDataURL(url).then(setQr).catch(() => setQr(null))
    }
  }, [etat])

  async function run(fn: () => Promise<void>, e: FormEvent) {
    e.preventDefault()
    setErr(null)
    setBusy(true)
    try {
      await fn()
    } catch (x) {
      setErr((x as Error).message)
    } finally {
      setBusy(false)
    }
  }

  const codeField = (
    <input
      className="input"
      inputMode="numeric"
      autoComplete="one-time-code"
      maxLength={6}
      placeholder="Code à 6 chiffres"
      value={code}
      onChange={(e) => setCode(e.target.value)}
      required
    />
  )

  return (
    <main className="grid min-h-screen place-items-center bg-ink p-4">
      <div className="card w-full max-w-sm space-y-4">
        <div className="flex items-center gap-2 text-ink">
          <ShieldCheck className="text-brand" />
          <h1 className="text-lg font-semibold">Console Diaspo Niger</h1>
        </div>
        {etat.k === 'deconnecte' && etat.message && (
          <p role="status" className="rounded bg-blue-50 p-2 text-sm text-blue-800">
            {etat.message}
          </p>
        )}
        {etat.k === 'enrolement' ? (
          <form onSubmit={(e) => run(() => confirmerEnrolement(code), e)} className="space-y-3">
            <p className="text-sm">
              Le second facteur est obligatoire. Scannez ce code dans votre application
              d'authentification, puis saisissez le code à 6 chiffres.
            </p>
            {qr && <img src={qr} alt="Code QR d'enrôlement" className="mx-auto h-44 w-44" />}
            <p className="break-all text-center font-mono text-xs text-slate-500">{etat.secret.secretKey}</p>
            {codeField}
            <button className="btn btn-primary w-full justify-center" disabled={busy}>
              Activer
            </button>
          </form>
        ) : etat.k === 'second_facteur' ? (
          <form onSubmit={(e) => run(() => validerCode(code), e)} className="space-y-3">
            <p className="text-sm">Saisissez le code de votre application d'authentification.</p>
            {codeField}
            <button className="btn btn-primary w-full justify-center" disabled={busy}>
              Valider
            </button>
          </form>
        ) : (
          <form onSubmit={(e) => run(() => connexion(email, mdp), e)} className="space-y-3">
            <label className="block text-sm">
              Adresse e-mail
              <input className="input mt-1" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </label>
            <label className="block text-sm">
              Mot de passe
              <input className="input mt-1" type="password" autoComplete="current-password" value={mdp} onChange={(e) => setMdp(e.target.value)} required />
            </label>
            <button className="btn btn-primary w-full justify-center" disabled={busy || etat.k === 'chargement'}>
              Se connecter
            </button>
            <button type="button" className="w-full text-center text-sm text-brand underline" onClick={() => void oublie()}>
              Mot de passe oublié
            </button>
          </form>
        )}
        {info && (
          <p role="status" className="text-sm text-blue-800">
            {info}
          </p>
        )}
        {err && (
          <p role="alert" className="text-sm text-red-600">
            {err}
          </p>
        )}
      </div>
    </main>
  )
}
