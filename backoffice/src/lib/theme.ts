const CLE = 'theme-sombre'

export function themeSombreActif(): boolean {
  try { return localStorage.getItem(CLE) === '1' } catch { return false }
}

export function appliquerTheme(sombre: boolean): void {
  document.documentElement.classList.toggle('dark', sombre)
  try { localStorage.setItem(CLE, sombre ? '1' : '0') } catch { /* stockage indisponible : le thème vaut pour cette page */ }
}
