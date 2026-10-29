/** Neutralise l'injection de formule tableur : une cellule qui commence par = + - @ est préfixée. */
const cellule = (v: unknown): string => {
  let s = v === null || v === undefined ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v)
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`
  return `"${s.replace(/"/g, '""')}"`
}

export function versCsv(colonnes: string[], lignes: Record<string, unknown>[]): string {
  const tete = colonnes.map(cellule).join(',')
  const corps = lignes.map((l) => colonnes.map((c) => cellule(l[c])).join(','))
  return [tete, ...corps].join('\r\n')
}

export function telechargerCsv(nom: string, contenu: string): void {
  const blob = new Blob(['﻿' + contenu], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = nom
  a.click()
  URL.revokeObjectURL(url)
}
