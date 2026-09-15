//! Surface exposée à Dart par Flutter Rust Bridge (spike).
//!
//! Volontairement étroite : des octets et des chaînes entrent, des octets,
//! des DTO plats et des codes d'erreur sortent. `Moteur` est opaque — Dart
//! n'en voit qu'une poignée, jamais l'état MLS ni les clés.

use std::path::Path;

use flutter_rust_bridge::frb;

use crate::engine::{MlsEngine, Processed};

/// Poignée opaque sur le moteur. FRB la range derrière un `RwLock` : les
/// méthodes `&mut self` s'exécutent une à la fois, ce qui est exactement la
/// règle « un seul écrivain de l'état MLS » du plan (§ 8).
#[frb(opaque)]
pub struct Moteur {
    interne: MlsEngine,
}

// `rusqlite::Connection` n'est pas `Sync`, mais tout accès passe par les
// méthodes `&mut self`, sérialisées par le verrou de FRB ; `identity()` ne
// touche pas la connexion. Acceptable pour le spike, à revoir avec un
// `Mutex` explicite dans le moteur de production.
unsafe impl Sync for Moteur {}

#[derive(Debug, Clone)]
pub struct MembreDto {
    pub leaf_index: u32,
    pub identity: String,
}

#[derive(Debug, Clone)]
pub struct InstantaneDto {
    pub epoch: u64,
    pub membres: Vec<MembreDto>,
}

#[derive(Debug, Clone)]
pub struct CommitDto {
    pub commit: Vec<u8>,
    pub welcome: Option<Vec<u8>>,
    pub group_info: Option<Vec<u8>>,
}

#[derive(Debug, Clone)]
pub enum EntrantDto {
    Application { clair: Vec<u8> },
    Commit { instantane: InstantaneDto },
    Proposition,
    Ignore,
}

fn code(e: crate::engine::MlsError) -> anyhow::Error {
    anyhow::anyhow!("{e}")
}

/// Déchiffre un message pour en faire un APERÇU de notification, sans
/// toucher à l'état qui fait foi (plan § 8).
///
/// Fonction libre, et non méthode de [`Moteur`] : l'isolate de notification
/// n'a pas la poignée de l'application, et ne doit surtout pas la partager —
/// deux écrivains sur le même cliquet rendraient la conversation illisible.
/// Il ouvre sa propre copie jetable, le temps d'un message.
pub fn apercu_sans_etat(
    db_path: String,
    user_id: String,
    device_id: String,
    conversation_id: String,
    message: Vec<u8>,
    aad: Vec<u8>,
) -> anyhow::Result<Vec<u8>> {
    crate::engine::preview_without_state(
        std::path::Path::new(&db_path),
        &user_id,
        &device_id,
        &conversation_id,
        &message,
        &aad,
    )
    .map_err(code)
}

fn instantane(s: crate::engine::GroupSnapshot) -> InstantaneDto {
    InstantaneDto {
        epoch: s.epoch,
        membres: s
            .members
            .into_iter()
            .map(|m| MembreDto {
                leaf_index: m.leaf_index,
                identity: String::from_utf8_lossy(&m.identity).into_owned(),
            })
            .collect(),
    }
}

fn commit(c: crate::engine::CommitOut) -> CommitDto {
    CommitDto {
        commit: c.commit,
        welcome: c.welcome,
        group_info: c.group_info,
    }
}

impl Moteur {
    /// Ouvre (ou crée) la base SQLite du moteur pour cet appareil.
    pub fn ouvrir(db_path: String, user_id: String, device_id: String) -> anyhow::Result<Moteur> {
        Ok(Moteur {
            interne: MlsEngine::open(Path::new(&db_path), &user_id, &device_id).map_err(code)?,
        })
    }

    #[frb(sync)]
    pub fn identite(&self) -> String {
        String::from_utf8_lossy(self.interne.identity()).into_owned()
    }

    /// Clé publique de signature de l'appareil (à publier dans `mls_devices`).
    #[frb(sync)]
    pub fn cle_signature_publique(&self) -> Vec<u8> {
        self.interne.public_signature_key().to_vec()
    }

    /// Credential MLS sérialisée de l'appareil (à publier dans `mls_devices`).
    #[frb(sync)]
    pub fn credential(&self) -> anyhow::Result<Vec<u8>> {
        self.interne.credential_bytes().map_err(code)
    }

    pub fn creer_key_packages(&mut self, n: u32, dernier_recours: bool) -> anyhow::Result<Vec<Vec<u8>>> {
        self.interne
            .create_key_packages(n as usize, dernier_recours)
            .map_err(code)
    }

    pub fn creer_groupe(&mut self, conversation_id: String) -> anyhow::Result<InstantaneDto> {
        self.interne
            .create_group(&conversation_id)
            .map(instantane)
            .map_err(code)
    }

    pub fn ajouter_membres(&mut self, conversation_id: String, key_packages: Vec<Vec<u8>>, aad: Vec<u8>) -> anyhow::Result<CommitDto> {
        self.interne
            .add_members(&conversation_id, &key_packages, &aad)
            .map(commit)
            .map_err(code)
    }

    pub fn retirer_membres(&mut self, conversation_id: String, leaf_indices: Vec<u32>, aad: Vec<u8>) -> anyhow::Result<CommitDto> {
        self.interne
            .remove_members(&conversation_id, &leaf_indices, &aad)
            .map(commit)
            .map_err(code)
    }

    pub fn fusionner_commit_en_attente(&mut self, conversation_id: String) -> anyhow::Result<InstantaneDto> {
        self.interne
            .merge_pending_commit(&conversation_id)
            .map(instantane)
            .map_err(code)
    }

    pub fn jeter_commit_en_attente(&mut self, conversation_id: String) -> anyhow::Result<()> {
        self.interne.clear_pending_commit(&conversation_id).map_err(code)
    }

    pub fn traiter_welcome(&mut self, conversation_id: String, welcome: Vec<u8>) -> anyhow::Result<InstantaneDto> {
        self.interne
            .process_welcome(&conversation_id, &welcome)
            .map(instantane)
            .map_err(code)
    }

    pub fn exporter_group_info(&mut self, conversation_id: String) -> anyhow::Result<Vec<u8>> {
        self.interne.export_group_info(&conversation_id).map_err(code)
    }

    pub fn rejoindre_par_commit_externe(&mut self, conversation_id: String, group_info: Vec<u8>, aad: Vec<u8>) -> anyhow::Result<CommitDto> {
        self.interne
            .join_by_external_commit(&conversation_id, &group_info, &aad)
            .map(commit)
            .map_err(code)
    }

    pub fn chiffrer(&mut self, conversation_id: String, clair: Vec<u8>, aad: Vec<u8>) -> anyhow::Result<Vec<u8>> {
        self.interne.encrypt(&conversation_id, &clair, &aad).map_err(code)
    }

    pub fn traiter_entrant(&mut self, conversation_id: String, message: Vec<u8>, aad_attendu: Vec<u8>) -> anyhow::Result<EntrantDto> {
        Ok(match self
            .interne
            .process_incoming(&conversation_id, &message, &aad_attendu)
            .map_err(code)?
        {
            Processed::Application(clair) => EntrantDto::Application { clair },
            Processed::Commit(s) => EntrantDto::Commit { instantane: instantane(s) },
            Processed::Proposal => EntrantDto::Proposition,
            Processed::Ignored => EntrantDto::Ignore,
        })
    }

    /// Supprime l'état local d'un groupe (perdant de la course à la création).
    pub fn oublier_groupe(&mut self, conversation_id: String) -> anyhow::Result<()> {
        self.interne.forget_group(&conversation_id).map_err(code)
    }

    pub fn instantane(&mut self, conversation_id: String) -> anyhow::Result<InstantaneDto> {
        self.interne
            .snapshot(&conversation_id)
            .map(instantane)
            .map_err(code)
    }
}
