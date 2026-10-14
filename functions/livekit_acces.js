/**
 * Qui reçoit un jeton LiveKit, pour quelle salle, avec quels droits.
 *
 * **Pourquoi ce module existe.** `getLiveKitToken` trouvait la salle par
 * `group_calls.where("roomName", "==", roomName)` — un champ que le client
 * écrit lui-même (règle de création de `group_calls`), et que
 * `createLiveKitRoom`, appelable par tout compte, posait sans contrôle en
 * écrasant `group_calls/{roomName}`. N'importe quel compte se déclarait donc
 * participant d'une salle de son choix et recevait un jeton de PUBLICATION :
 * salon audio privé (`audio-room-…`), podcast en direct (`live-podcast-…`),
 * ou appel de groupe dont il prenait le document et la place d'hôte.
 *
 * Désormais la décision ne lit que ce que le client ne peut pas falsifier :
 *   · appel de groupe : la salle EST l'identifiant du document
 *     `group_calls/{id}`, lu par son id ; hôte ou participant, appel non
 *     terminé ;
 *   · podcast en direct : un épisode `isLive` dont `livekitRoomName` a été
 *     posé par `startLivePodcast` ; écoute seule (l'hôte a son jeton par
 *     `startLivePodcast`) ;
 *   · salon audio : refusé ici — `getAudioRoomLiveKitToken` vérifie
 *     l'appartenance au salon.
 *
 * Module séparé, pur, pour être testable sans émulateur ni identifiants :
 * banc `tools/rules_tests/livekit_acces.mjs`.
 */

class RefusLiveKit extends Error {
  /** @param {string} code  code `HttpsError` ; @param {string} message */
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/**
 * @param {object} p
 * @param {string} p.roomName  salle demandée
 * @param {string} p.uid       appelant authentifié
 * @param {(id: string) => Promise<{id: string, data: object}|null>} p.lireAppelDeGroupe
 *        `group_calls/{id}` lu par son identifiant, ou null
 * @param {(salle: string) => Promise<boolean>} p.podcastEnDirect
 *        vrai si un épisode `isLive` porte ce `livekitRoomName`
 * @returns {Promise<object>} le grant LiveKit
 */
async function droitLiveKit({ roomName, uid, lireAppelDeGroupe, podcastEnDirect }) {
  if (!uid) throw new RefusLiveKit("unauthenticated", "Session requise");
  if (typeof roomName !== "string" || roomName.length === 0 || roomName.length > 200) {
    throw new RefusLiveKit("invalid-argument", "Room name is required and must be a string");
  }

  if (roomName.startsWith("audio-room-")) {
    throw new RefusLiveKit("permission-denied", "Use getAudioRoomLiveKitToken for audio rooms");
  }

  if (roomName.startsWith("live-podcast-")) {
    if (!(await podcastEnDirect(roomName))) {
      throw new RefusLiveKit("not-found", "No live podcast for this room");
    }
    return {
      room: roomName,
      roomJoin: true,
      canPublish: false,
      canPublishData: false,
      canSubscribe: true,
    };
  }

  // Un identifiant de document Firestore ne contient pas de « / ».
  if (roomName.includes("/")) {
    throw new RefusLiveKit("invalid-argument", "Invalid room name");
  }
  const appel = await lireAppelDeGroupe(roomName);
  if (!appel) throw new RefusLiveKit("not-found", "No group call for this room");
  const data = appel.data || {};
  if (data.status === "ended") {
    throw new RefusLiveKit("failed-precondition", "This call has ended");
  }
  const participants = Array.isArray(data.participantIds) ? data.participantIds : [];
  if (!participants.includes(uid) && data.hostId !== uid) {
    throw new RefusLiveKit("permission-denied", "You are not a participant in this call");
  }
  return {
    room: appel.id,
    roomJoin: true,
    canPublish: true,
    canPublishData: true,
    canSubscribe: true,
    canUpdateOwnMetadata: true,
  };
}

module.exports = { droitLiveKit, RefusLiveKit };
