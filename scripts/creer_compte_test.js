// Cree -- ou reinitialise -- un compte de test Firebase Auth pour l'app.
//
//   node scripts/creer_compte_test.js
//   node scripts/creer_compte_test.js --email test.diaspo2@example.com --nom "Compte Test 2"
//   node scripts/creer_compte_test.js --cle chemin/vers/serviceAccount.json
//
// Le mot de passe n'est PAS dans ce fichier : il est tire au hasard a chaque
// execution et affiche une seule fois. Relancer le script sur une adresse qui
// existe deja ne cree pas de doublon -- ca reinitialise son mot de passe, ce
// qui est la seule facon de recuperer un compte de test dont le mot de passe
// a ete perdu (l'adresse par defaut est en `example.com`, domaine reserve par
// la RFC 2606 : aucun e-mail de reinitialisation n'y arrivera jamais).
//
// Le compte n'existe que dans Firebase Auth. Sa ligne `users` Supabase, sa
// session gotrue et son profil sont crees par l'app elle-meme a la premiere
// connexion (SupabaseAuthBridge.syncWithFirebase + _upsertUserToSupabase).
// Rien a faire de ce cote.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');

const EMAIL_DEFAUT = 'test.diaspo@example.com';

// ASCII uniquement, volontairement : l'Edge Function `auth-firebase-exchange`
// decode le JWT Firebase avec atob() et rend `MaÃ¯daoua` pour `Maïdaoua`.
// Un nom accentue ici reviendrait mojibake dans `users.display_name`.
const NOM_DEFAUT = 'Compte Test';

function lireArguments(argv) {
  const opts = {};
  for (let i = 0; i < argv.length; i += 1) {
    const cle = argv[i];
    if (cle === '--email' || cle === '--nom' || cle === '--cle') {
      opts[cle.slice(2)] = argv[i + 1];
      i += 1;
    }
  }
  return opts;
}

/// Chemin du compte de service, par ordre de preference :
/// l'argument --cle, la variable d'environnement, la ligne
/// GOOGLE_APPLICATION_CREDENTIALS du .env, puis le premier
/// *-adminsdk-*.json trouve a la racine. Tous ces fichiers sont ignores par
/// git (.gitignore ligne 9) : aucun risque de les committer.
function trouverCle(cleArg) {
  const candidats = [cleArg, process.env.GOOGLE_APPLICATION_CREDENTIALS];

  const env = path.join(process.cwd(), '.env');
  if (fs.existsSync(env)) {
    const ligne = fs
      .readFileSync(env, 'utf8')
      .split(/\r?\n/)
      .find((l) => l.startsWith('GOOGLE_APPLICATION_CREDENTIALS='));
    if (ligne) candidats.push(ligne.split('=').slice(1).join('=').trim());
  }

  const racine = fs.readdirSync(process.cwd());
  const adminsdk = racine.find((f) => /-adminsdk-.*\.json$/.test(f));
  if (adminsdk) candidats.push(path.join(process.cwd(), adminsdk));

  return candidats.find((c) => c && fs.existsSync(c));
}

/// Mot de passe conforme a `Validators.password` (lib/core/utils/validators.dart) :
/// 8 caracteres minimum, une majuscule, une minuscule, un chiffre, un caractere
/// special. Sans I/l/1/O/0 (illisibles), sans $ ni backtick (colles dans un
/// terminal), et assez court pour se taper au clavier d'un telephone.
function genererMotDePasse() {
  const majuscules = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const minuscules = 'abcdefghijkmnopqrstuvwxyz';
  const chiffres = '23456789';
  const speciaux = '!@#%*?-_+=';
  const tout = majuscules + minuscules + chiffres + speciaux;

  const pioche = (alphabet) => alphabet[crypto.randomInt(alphabet.length)];
  const caracteres = [
    pioche(majuscules),
    pioche(minuscules),
    pioche(chiffres),
    pioche(speciaux),
  ];
  while (caracteres.length < 14) caracteres.push(pioche(tout));

  // Melange de Fisher-Yates : sinon les quatre classes obligatoires restent
  // toujours dans le meme ordre en tete du mot de passe.
  for (let i = caracteres.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(i + 1);
    [caracteres[i], caracteres[j]] = [caracteres[j], caracteres[i]];
  }
  return caracteres.join('');
}

async function main() {
  const opts = lireArguments(process.argv.slice(2));
  const email = opts.email || EMAIL_DEFAUT;
  const nom = opts.nom || NOM_DEFAUT;

  const cle = trouverCle(opts.cle);
  if (!cle) {
    console.error(
      'Compte de service introuvable. Lancer depuis la racine du depot, ou\n' +
        'passer --cle <chemin vers le json admin SDK>.',
    );
    process.exit(1);
  }
  admin.initializeApp({
    credential: admin.credential.cert(require(path.resolve(cle))),
  });

  const motDePasse = genererMotDePasse();
  let compte;
  let existait = false;

  try {
    compte = await admin.auth().getUserByEmail(email);
    existait = true;
    // `emailVerified: true` n'ouvre aucune porte -- l'app ne verifie nulle part
    // ce drapeau -- mais evite qu'une future garde de verification bloque le
    // compte de test un jour ou l'autre.
    compte = await admin.auth().updateUser(compte.uid, {
      password: motDePasse,
      displayName: nom,
      emailVerified: true,
      disabled: false,
    });
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    compte = await admin.auth().createUser({
      email,
      password: motDePasse,
      displayName: nom,
      emailVerified: true,
    });
  }

  console.log('');
  console.log(existait ? 'Compte existant : mot de passe reinitialise.' : 'Compte cree.');
  console.log('');
  console.log('  E-mail        : ' + compte.email);
  console.log('  Mot de passe  : ' + motDePasse);
  console.log('  Nom affiche   : ' + compte.displayName);
  console.log('  uid Firebase  : ' + compte.uid);
  console.log('');
  console.log('Le mot de passe ne sera plus jamais affiche. Le noter maintenant ;');
  console.log('en cas de perte, relancer ce script sur la meme adresse.');
  console.log('');
  console.log('A la premiere connexion, l app enchaine consentement > configuration');
  console.log('du profil > intro (drapeaux locaux a l appareil, pas au compte).');
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('Echec : ' + (e.message || e));
    process.exit(1);
  });
