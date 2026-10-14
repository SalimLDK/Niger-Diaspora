// Banc : qui reçoit un jeton LiveKit, pour quelle salle.
//
//   node tools/rules_tests/livekit_acces.mjs
//
// Condition : 0 cas en ÉCHEC.
//
// Ni émulateur, ni réseau, ni identifiants : `functions/livekit_acces.js` est
// une fonction pure, à qui l'on passe les lectures Firestore.
//
// ── L'attaque que ce banc rejoue ─────────────────────────────────────────
//
// `getLiveKitToken` trouvait la salle par `where("roomName", "==", …)` sur
// `group_calls` — un champ écrit par le client, et que `createLiveKitRoom`
// (appelable par tout compte) posait en écrasant `group_calls/{roomName}`.
// Un compte quelconque se déclarait participant et recevait un jeton de
// PUBLICATION pour un salon audio privé, un podcast en direct, ou un appel de
// groupe dont il prenait la place d'hôte (cas 1 à 4).
//
// ── Un banc qui ne sait pas échouer ne prouve rien ────────────────────────
//
// Lancé avec `LIVEKIT_ACCES=<chemin>` sur une copie qui rejoue l'ancienne
// règle (« premier document dont roomName correspond, appelant dedans »),
// huit cas tombent : les attaques 1 à 3 réussissent (jeton de publication),
// et les vrais appels de groupe (6, 7) n'obtiennent RIEN — l'app ne pose
// jamais `roomName`, la salle est l'identifiant du document. Vérifié le
// 2026-10-14.

import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const chemin = process.env.LIVEKIT_ACCES || "../../functions/livekit_acces.js";
const { droitLiveKit } = require(chemin);

// Firestore simulé. `group_calls` par identifiant ; l'attaquant a pu y créer
// des documents portant un `roomName` de son choix.
const appels = new Map([
  ["appelVrai", { hostId: "hote", participantIds: ["hote", "invite"], status: "active" }],
  ["appelFini", { hostId: "hote", participantIds: ["hote", "invite"], status: "ended" }],
  // Fabriqué par l'attaquant (règle de création ou createLiveKitRoom) :
  ["faux1", { roomName: "audio-room-prive", hostId: "intrus", participantIds: ["intrus"] }],
  ["faux2", { roomName: "live-podcast-p1-1", hostId: "intrus", participantIds: ["intrus"] }],
  ["faux3", { roomName: "appelVrai", hostId: "intrus", participantIds: ["intrus"] }],
]);
const podcastsEnDirect = new Set(["live-podcast-p1-1"]);

const lectures = {
  lireAppelDeGroupe: async (id) => (appels.has(id) ? { id, data: appels.get(id) } : null),
  podcastEnDirect: async (salle) => podcastsEnDirect.has(salle),
  // Pour la copie « ancienne règle » : la recherche par champ.
  chercherParRoomName: async (salle) => {
    for (const [id, data] of appels) if (data.roomName === salle) return { id, data };
    return null;
  },
};

const resultats = [];
async function cas(n, libelle, appel, attendu) {
  let obtenu;
  try {
    const grant = await droitLiveKit({ ...lectures, ...appel });
    obtenu = grant.canPublish ? `publication ${grant.room}` : `écoute ${grant.room}`;
  } catch (e) {
    obtenu = `refus ${e.code}`;
  }
  resultats.push({ n, libelle, attendu, obtenu, verdict: obtenu === attendu ? "OK" : "ÉCHEC" });
}

await cas(1, "salon audio privé réclamé par un étranger",
  { roomName: "audio-room-prive", uid: "intrus" }, "refus permission-denied");
await cas(2, "podcast en direct : l'étranger ne publie pas",
  { roomName: "live-podcast-p1-1", uid: "intrus" }, "écoute live-podcast-p1-1");
await cas(3, "appel de groupe réclamé par son nom de salle détourné",
  { roomName: "appelVrai", uid: "intrus" }, "refus permission-denied");
await cas(4, "témoin : qui crée son appel en a la salle, et seulement elle",
  { roomName: "faux1", uid: "intrus" }, "publication faux1");
await cas(5, "appel terminé",
  { roomName: "appelFini", uid: "invite" }, "refus failed-precondition");
await cas(6, "témoin : l'invité rejoint l'appel de groupe",
  { roomName: "appelVrai", uid: "invite" }, "publication appelVrai");
await cas(7, "témoin : l'hôte rejoint l'appel de groupe",
  { roomName: "appelVrai", uid: "hote" }, "publication appelVrai");
await cas(8, "podcast qui n'est pas en direct",
  { roomName: "live-podcast-p9-9", uid: "invite" }, "refus not-found");
await cas(9, "chemin dans le nom de salle",
  { roomName: "a/b", uid: "invite" }, "refus invalid-argument");
await cas(10, "sans session",
  { roomName: "appelVrai", uid: "" }, "refus unauthenticated");

for (const r of resultats) {
  console.log(`${String(r.n).padStart(2)} | ${r.verdict.padEnd(5)} | ${r.libelle} | attendu: ${r.attendu} | obtenu: ${r.obtenu}`);
}
const echecs = resultats.filter((r) => r.verdict !== "OK").length;
console.log(`\n${echecs} ÉCHEC`);
process.exit(echecs ? 1 : 0);
