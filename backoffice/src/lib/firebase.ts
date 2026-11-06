import { initializeApp } from 'firebase/app'
import { browserSessionPersistence, getAuth, setPersistence } from 'firebase/auth'
import { env } from './env'

export const fbApp = initializeApp({
  apiKey: env.firebaseApiKey,
  appId: env.firebaseAppId,
  projectId: env.firebaseProjectId,
  authDomain: env.firebaseAuthDomain,
})
export const fbAuth = getAuth(fbApp)
// Session de l'onglet seulement : fermer l'onglet déconnecte la console.
void setPersistence(fbAuth, browserSessionPersistence)
