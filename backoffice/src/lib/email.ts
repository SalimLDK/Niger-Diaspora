/** « amina.n@exemple.com » → « a•••@e•••.com ». Un e-mail absent ou mal formé donne une chaîne vide : on n'affiche jamais le brut. */
export function masquerEmail(email: string | null | undefined): string {
  const m = /^(.)[^@]*@(.)[^@]*(\.[^.@]+)$/.exec(email ?? '')
  return m ? `${m[1]}•••@${m[2]}•••${m[3]}` : ''
}
