const need = (k: string): string => {
  const v = import.meta.env[k] as string | undefined
  if (!v) throw new Error(`Variable manquante : ${k} (voir .env.example)`)
  return v
}
export const env = {
  firebaseApiKey: need('VITE_FIREBASE_API_KEY'),
  firebaseAppId: need('VITE_FIREBASE_APP_ID'),
  firebaseProjectId: need('VITE_FIREBASE_PROJECT_ID'),
  firebaseAuthDomain: need('VITE_FIREBASE_AUTH_DOMAIN'),
  supabaseUrl: need('VITE_SUPABASE_URL'),
  supabaseAnonKey: need('VITE_SUPABASE_ANON_KEY'),
}
