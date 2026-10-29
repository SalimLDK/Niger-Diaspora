import {
  collection, doc, getDoc, getDocs, limit, orderBy, query, runTransaction, serverTimestamp,
  getFirestore, type Timestamp,
} from 'firebase/firestore'
import { getApp } from 'firebase/app'
import { fbAuth } from './firebase'

const db = () => getFirestore(getApp())
const SETTINGS = ['app_config', 'settings'] as const

export type Section = Record<string, unknown>
export interface Entree {
  id: string
  section: string
  before: Section | null
  after: Section | null
  by: string
  at: Date | null
  kind: string
  reason?: string
}

export async function lireReglages(): Promise<Record<string, Section>> {
  const snap = await getDoc(doc(db(), ...SETTINGS))
  const data = (snap.data() ?? {}) as Record<string, unknown>
  const out: Record<string, Section> = {}
  for (const [k, v] of Object.entries(data)) {
    if (v && typeof v === 'object' && !Array.isArray(v) && !('toDate' in (v as object))) out[k] = v as Section
  }
  return out
}

export async function lireHistorique(): Promise<Entree[]> {
  const snap = await getDocs(query(collection(db(), 'app_config_history'), orderBy('at', 'desc'), limit(50)))
  return snap.docs.map((d) => {
    const x = d.data() as Record<string, unknown>
    return {
      id: d.id,
      section: String(x.section ?? ''),
      before: (x.before as Section | null) ?? null,
      after: (x.after as Section | null) ?? null,
      by: String(x.by ?? ''),
      at: (x.at as Timestamp | undefined)?.toDate?.() ?? null,
      kind: String(x.kind ?? 'update'),
      reason: x.reason ? String(x.reason) : undefined,
    }
  })
}

/**
 * Remplace une section. Même protocole que le panneau Flutter : une entrée d'historique neuve et le document
 * de réglages qui la cite (`lastChangeId`) dans la MÊME transaction. Les règles Firestore l'exigent et
 * réservent l'écriture au super-administrateur.
 */
export async function ecrireSection(
  section: string, data: Section, raison: string, kind: 'update' | 'restore' = 'update', restoredFrom?: string,
): Promise<void> {
  const uid = fbAuth.currentUser?.uid
  if (!uid) throw new Error('Aucune session : écriture refusée.')
  if (!raison.trim()) throw new Error('Un motif est obligatoire.')
  const histo = doc(collection(db(), 'app_config_history'))
  const ref = doc(db(), ...SETTINGS)
  await runTransaction(db(), async (tx) => {
    const actuel = await tx.get(ref)
    const avant = ((actuel.data() as Record<string, unknown> | undefined)?.[section] as Section | undefined) ?? null
    tx.set(histo, {
      section, before: avant, after: data, by: uid, at: serverTimestamp(), kind,
      ...(restoredFrom ? { restoredFrom } : {}), reason: raison.trim(),
    })
    tx.set(ref, {
      [section]: data, updatedBy: uid, lastUpdated: serverTimestamp(), lastChangeId: histo.id,
    }, { merge: true })
  })
}

/** Valide le texte saisi : un objet JSON, rien d'autre. */
export function analyserSection(texte: string): { ok: true; valeur: Section } | { ok: false; erreur: string } {
  try {
    const v: unknown = JSON.parse(texte)
    if (!v || typeof v !== 'object' || Array.isArray(v)) return { ok: false, erreur: 'Une section doit être un objet JSON.' }
    return { ok: true, valeur: v as Section }
  } catch {
    return { ok: false, erreur: 'JSON invalide.' }
  }
}
