//! Façade du moteur MLS, telle que le plan (§ 7.2) la destine à Dart.
//!
//! Dart ne voit jamais une clé privée ni un état de groupe : il tend des
//! octets (KeyPackage, Welcome, commit, ciphertext) et en reçoit d'autres.
//! Les erreurs sont des codes, jamais du contenu.

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use openmls::prelude::tls_codec::{Deserialize as TlsDeserialize, Serialize as TlsSerialize};
use openmls::messages::group_info::GroupInfo;
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_traits::random::OpenMlsRand;
use openmls_traits::OpenMlsProvider;
use rusqlite::Connection;

use crate::provider::{DiaspoProvider, ProviderError, Storage};

const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;

/// Combien d'epochs passés restent déchiffrables. Un message émis juste
/// avant un commit, livré juste après, doit encore se lire.
const MAX_PAST_EPOCHS: usize = 3;

#[derive(Debug, thiserror::Error)]
pub enum MlsError {
    #[error("provider")]
    Provider(#[from] ProviderError),
    #[error("sqlite")]
    Sqlite(#[from] rusqlite::Error),
    #[error("identity_missing")]
    IdentityMissing,
    #[error("group_unknown")]
    GroupUnknown,
    #[error("aad_mismatch")]
    AadMismatch,
    #[error("not_application_message")]
    NotApplicationMessage,
    #[error("openmls:{0}")]
    OpenMls(String),
}

/// Réduit une erreur OpenMLS à son nom de variante : assez pour
/// `mls_diagnostics`, jamais un octet de contenu.
fn code<E: std::fmt::Debug>(e: E) -> MlsError {
    let debug = format!("{e:?}");
    let variante = debug
        .split(|c: char| !c.is_alphanumeric() && c != '_')
        .next()
        .unwrap_or("Unknown")
        .to_string();
    MlsError::OpenMls(variante)
}

#[derive(Debug)]
pub struct GroupSnapshot {
    pub epoch: u64,
    pub members: Vec<MemberInfo>,
}

#[derive(Debug)]
pub struct MemberInfo {
    pub leaf_index: u32,
    pub identity: Vec<u8>,
}

#[derive(Debug)]
pub struct CommitOut {
    pub commit: Vec<u8>,
    pub welcome: Option<Vec<u8>>,
    pub group_info: Option<Vec<u8>>,
}

#[derive(Debug)]
pub enum Processed {
    Application(Vec<u8>),
    Commit(GroupSnapshot),
    Proposal,
    Ignored,
}

pub struct MlsEngine {
    provider: DiaspoProvider,
    meta: Connection,
    signer: SignatureKeyPair,
    credential_with_key: CredentialWithKey,
    identity: Vec<u8>,
    groups: HashMap<String, MlsGroup>,
    #[allow(dead_code)]
    db_path: PathBuf,
}

/// Charge un groupe depuis le cache mémoire, sinon depuis SQLite.
///
/// Fonction libre plutôt que méthode : elle n'emprunte que `groups` et le
/// stockage, ce qui laisse `signer` et `provider` disponibles à l'appelant.
fn charger<'a>(
    groups: &'a mut HashMap<String, MlsGroup>,
    storage: &Storage,
    conversation_id: &str,
) -> Result<&'a mut MlsGroup, MlsError> {
    if !groups.contains_key(conversation_id) {
        let loaded = MlsGroup::load(storage, &group_id(conversation_id))
            .map_err(code)?
            .ok_or(MlsError::GroupUnknown)?;
        groups.insert(conversation_id.to_string(), loaded);
    }
    Ok(groups.get_mut(conversation_id).expect("inséré juste au-dessus"))
}

fn group_id(conversation_id: &str) -> GroupId {
    GroupId::from_slice(conversation_id.as_bytes())
}

fn create_config() -> MlsGroupCreateConfig {
    MlsGroupCreateConfig::builder()
        .ciphersuite(CIPHERSUITE)
        .use_ratchet_tree_extension(true)
        .max_past_epochs(MAX_PAST_EPOCHS)
        // Les messages applicatifs partent chiffrés ; les commits externes
        // arrivent forcément en clair, il faut les accepter.
        .wire_format_policy(MIXED_CIPHERTEXT_WIRE_FORMAT_POLICY)
        .build()
}

fn join_config() -> MlsGroupJoinConfig {
    MlsGroupJoinConfig::builder()
        .use_ratchet_tree_extension(true)
        .max_past_epochs(MAX_PAST_EPOCHS)
        .wire_format_policy(MIXED_CIPHERTEXT_WIRE_FORMAT_POLICY)
        .build()
}

fn snapshot_of(group: &MlsGroup) -> GroupSnapshot {
    GroupSnapshot {
        epoch: group.epoch().as_u64(),
        members: group
            .members()
            .map(|m| MemberInfo {
                leaf_index: m.index.u32(),
                identity: BasicCredential::try_from(m.credential)
                    .map(|c| c.identity().to_vec())
                    .unwrap_or_default(),
            })
            .collect(),
    }
}

fn commit_out(
    commit: MlsMessageOut,
    welcome: Option<MlsMessageOut>,
    group_info: Option<GroupInfo>,
) -> Result<CommitOut, MlsError> {
    Ok(CommitOut {
        commit: commit.to_bytes().map_err(code)?,
        welcome: welcome.map(|w| w.to_bytes()).transpose().map_err(code)?,
        group_info: group_info
            .map(|gi| gi.tls_serialize_detached())
            .transpose()
            .map_err(code)?,
    })
}

impl MlsEngine {
    /// Ouvre le moteur ; crée l'identité de l'appareil au premier appel,
    /// la recharge ensuite. Idempotent.
    pub fn open(db_path: &Path, user_id: &str, device_id: &str) -> Result<Self, MlsError> {
        let provider = DiaspoProvider::open(db_path)?;
        let meta = Connection::open(db_path)?;
        // Une INSTALLATION par (compte, appareil) : l'identité MLS porte un
        // suffixe tiré au sort à la création de la base. Une réinstallation
        // (base perdue) produit donc une identité NEUVE — c'est ce qui permet
        // aux autres membres de voir un appareil à réajouter, au lieu d'un
        // membre existant dont la clé aurait changé sans prévenir (§ 5.6).
        meta.execute_batch(
            "CREATE TABLE IF NOT EXISTS diaspo_installation (
                cle TEXT PRIMARY KEY,
                identity BLOB NOT NULL,
                public_key BLOB NOT NULL
            );",
        )?;

        let cle = format!("{user_id}:{device_id}");
        let existing: Option<(Vec<u8>, Vec<u8>)> = meta
            .query_row(
                "SELECT identity, public_key FROM diaspo_installation WHERE cle = ?1",
                [&cle],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .ok();

        let (identity, signer) = match existing {
            Some((identity, public_key)) => (
                identity,
                SignatureKeyPair::read(
                    provider.storage(),
                    &public_key,
                    CIPHERSUITE.signature_algorithm(),
                )
                .ok_or(MlsError::IdentityMissing)?,
            ),
            None => {
                let signer =
                    SignatureKeyPair::new(CIPHERSUITE.signature_algorithm()).map_err(code)?;
                signer.store(provider.storage()).map_err(code)?;
                // 8 octets aléatoires du fournisseur crypto, en hexadécimal.
                let alea = provider.rand().random_vec(8).map_err(code)?;
                let suffixe: String = alea.iter().map(|o| format!("{o:02x}")).collect();
                let identity = format!("{cle}:{suffixe}").into_bytes();
                meta.execute(
                    "INSERT INTO diaspo_installation (cle, identity, public_key) VALUES (?1, ?2, ?3)",
                    (&cle, &identity, signer.public()),
                )?;
                (identity, signer)
            }
        };

        let credential_with_key = CredentialWithKey {
            credential: BasicCredential::new(identity.clone()).into(),
            signature_key: signer.public().into(),
        };

        Ok(Self {
            provider,
            meta,
            signer,
            credential_with_key,
            identity,
            groups: HashMap::new(),
            db_path: db_path.to_path_buf(),
        })
    }

    pub fn identity(&self) -> &[u8] {
        &self.identity
    }

    pub fn public_signature_key(&self) -> &[u8] {
        self.signer.public()
    }

    /// Credential MLS de cet appareil, sérialisée (TLS) : ce que le registre
    /// publie à côté de la clé de signature.
    pub fn credential_bytes(&self) -> Result<Vec<u8>, MlsError> {
        self.credential_with_key
            .credential
            .tls_serialize_detached()
            .map_err(code)
    }

    /// Produit `n` KeyPackages sérialisés (TLS), à publier sur le serveur.
    pub fn create_key_packages(&self, n: usize, last_resort: bool) -> Result<Vec<Vec<u8>>, MlsError> {
        (0..n)
            .map(|_| {
                let mut builder = KeyPackage::builder();
                if last_resort {
                    builder = builder.mark_as_last_resort();
                }
                let bundle = builder
                    .build(
                        CIPHERSUITE,
                        &self.provider,
                        &self.signer,
                        self.credential_with_key.clone(),
                    )
                    .map_err(code)?;
                bundle.key_package().tls_serialize_detached().map_err(code)
            })
            .collect()
    }

    pub fn create_group(&mut self, conversation_id: &str) -> Result<GroupSnapshot, MlsError> {
        let group = MlsGroup::new_with_group_id(
            &self.provider,
            &self.signer,
            &create_config(),
            group_id(conversation_id),
            self.credential_with_key.clone(),
        )
        .map_err(code)?;
        let snapshot = snapshot_of(&group);
        self.groups.insert(conversation_id.to_string(), group);
        Ok(snapshot)
    }

    /// Ajoute des membres à partir de leurs KeyPackages sérialisés. Le commit
    /// n'est PAS fusionné : l'appelant le publie d'abord (clé primaire
    /// `(conversation, epoch)` côté serveur), puis `merge_pending_commit`
    /// s'il a gagné, `clear_pending_commit` sinon.
    ///
    /// `aad` est posé explicitement : OpenMLS remet l'AAD à vide après chaque
    /// message sortant, donc un commit qui suit un message partirait sinon
    /// sans contexte (§ 6.1 du plan, piège relevé au spike).
    pub fn add_members(&mut self, conversation_id: &str, key_packages: &[Vec<u8>], aad: &[u8]) -> Result<CommitOut, MlsError> {
        let mut validated = Vec::with_capacity(key_packages.len());
        for bytes in key_packages {
            let kp_in = KeyPackageIn::tls_deserialize_exact(bytes).map_err(code)?;
            validated.push(
                kp_in
                    .validate(self.provider.crypto(), ProtocolVersion::Mls10)
                    .map_err(code)?,
            );
        }
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        group.set_aad(aad.to_vec());
        let (commit, welcome, group_info) = group
            .add_members(&self.provider, &self.signer, &validated)
            .map_err(code)?;
        commit_out(commit, Some(welcome), group_info)
    }

    pub fn remove_members(&mut self, conversation_id: &str, leaf_indices: &[u32], aad: &[u8]) -> Result<CommitOut, MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        group.set_aad(aad.to_vec());
        let indices: Vec<LeafNodeIndex> =
            leaf_indices.iter().map(|i| LeafNodeIndex::new(*i)).collect();
        let (commit, welcome, group_info) = group
            .remove_members(&self.provider, &self.signer, &indices)
            .map_err(code)?;
        commit_out(commit, welcome, group_info)
    }

    pub fn merge_pending_commit(&mut self, conversation_id: &str) -> Result<GroupSnapshot, MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        group.merge_pending_commit(&self.provider).map_err(code)?;
        Ok(snapshot_of(group))
    }

    pub fn clear_pending_commit(&mut self, conversation_id: &str) -> Result<(), MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        group
            .clear_pending_commit(self.provider.storage())
            .map_err(code)?;
        Ok(())
    }

    /// Rejoint un groupe depuis un Welcome sérialisé.
    pub fn process_welcome(&mut self, conversation_id: &str, welcome: &[u8]) -> Result<GroupSnapshot, MlsError> {
        let message = MlsMessageIn::tls_deserialize_exact(welcome).map_err(code)?;
        let welcome = match message.extract() {
            MlsMessageBodyIn::Welcome(w) => w,
            _ => return Err(MlsError::NotApplicationMessage),
        };
        let group = StagedWelcome::new_from_welcome(&self.provider, &join_config(), welcome, None)
            .map_err(code)?
            .into_group(&self.provider)
            .map_err(code)?;
        let snapshot = snapshot_of(&group);
        self.groups.insert(conversation_id.to_string(), group);
        Ok(snapshot)
    }

    /// GroupInfo (avec arbre) pour les jointures externes des groupes ouverts.
    pub fn export_group_info(&mut self, conversation_id: &str) -> Result<Vec<u8>, MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        group
            .export_group_info(self.provider.crypto(), &self.signer, true)
            .map_err(code)?
            .to_bytes()
            .map_err(code)
    }

    /// S'ajoute soi-même à un groupe depuis son GroupInfo (External Commit).
    /// Le commit rendu doit être publié puis traité par les membres.
    pub fn join_by_external_commit(&mut self, conversation_id: &str, group_info: &[u8], aad: &[u8]) -> Result<CommitOut, MlsError> {
        let verifiable = match MlsMessageIn::tls_deserialize_exact(group_info)
            .map_err(code)?
            .extract()
        {
            MlsMessageBodyIn::GroupInfo(gi) => gi,
            _ => return Err(MlsError::NotApplicationMessage),
        };
        let (group, bundle) = MlsGroup::external_commit_builder()
            .with_config(join_config())
            .with_aad(aad.to_vec())
            .build_group(&self.provider, verifiable, self.credential_with_key.clone())
            .map_err(code)?
            .load_psks(self.provider.storage())
            .map_err(code)?
            .build(self.provider.rand(), self.provider.crypto(), &self.signer, |_| true)
            .map_err(code)?
            .finalize(&self.provider)
            .map_err(code)?;
        self.groups.insert(conversation_id.to_string(), group);
        let (commit, welcome, group_info) = bundle.into_messages();
        Ok(CommitOut {
            commit: commit.to_bytes().map_err(code)?,
            welcome: welcome.map(|w| w.to_bytes()).transpose().map_err(code)?,
            group_info: group_info.map(|g| g.to_bytes()).transpose().map_err(code)?,
        })
    }

    pub fn encrypt(&mut self, conversation_id: &str, plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        group.set_aad(aad.to_vec());
        group
            .create_message(&self.provider, &self.signer, plaintext)
            .map_err(code)?
            .to_bytes()
            .map_err(code)
    }

    /// Traite un message entrant (application, commit ou proposition). L'AAD
    /// attendu est recomposé par l'appelant depuis les colonnes de la ligne.
    pub fn process_incoming(&mut self, conversation_id: &str, message: &[u8], expected_aad: &[u8]) -> Result<Processed, MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        let protocol_message = MlsMessageIn::tls_deserialize_exact(message)
            .map_err(code)?
            .try_into_protocol_message()
            .map_err(code)?;
        let processed = group
            .process_message(&self.provider, protocol_message)
            .map_err(code)?;
        if processed.aad() != expected_aad {
            return Err(MlsError::AadMismatch);
        }
        match processed.into_content() {
            ProcessedMessageContent::ApplicationMessage(app) => {
                Ok(Processed::Application(app.into_bytes()))
            }
            ProcessedMessageContent::StagedCommitMessage(staged) => {
                group.merge_staged_commit(&self.provider, *staged).map_err(code)?;
                Ok(Processed::Commit(snapshot_of(group)))
            }
            ProcessedMessageContent::ProposalMessage(proposal) => {
                group
                    .store_pending_proposal(self.provider.storage(), *proposal)
                    .map_err(code)?;
                Ok(Processed::Proposal)
            }
            ProcessedMessageContent::ExternalJoinProposalMessage(_)
            | ProcessedMessageContent::OwnPendingCommit
            | ProcessedMessageContent::OwnPrivateMessage => Ok(Processed::Ignored),
        }
    }

    pub fn snapshot(&mut self, conversation_id: &str) -> Result<GroupSnapshot, MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        Ok(snapshot_of(group))
    }

    /// Point d'extension appels (§ 7.2) : non câblé, mais la façade le porte.
    pub fn export_secret(&mut self, conversation_id: &str, label: &str, length: usize) -> Result<Vec<u8>, MlsError> {
        let group = charger(&mut self.groups, self.provider.storage(), conversation_id)?;
        group
            .export_secret(self.provider.crypto(), label, &[], length)
            .map_err(code)
    }

    /// Oublie un groupe local (état et secrets supprimés du stockage).
    ///
    /// Sert au perdant de la course à la création (§ 5.2) : deux appareils
    /// qui créent le même groupe en même temps ont deux secrets différents ;
    /// celui dont la réservation de l'epoch 0 est refusée jette le sien et
    /// attend un Welcome.
    pub fn forget_group(&mut self, conversation_id: &str) -> Result<(), MlsError> {
        let mut group = match self.groups.remove(conversation_id) {
            Some(g) => g,
            None => match MlsGroup::load(self.provider.storage(), &group_id(conversation_id)).map_err(code)? {
                Some(g) => g,
                None => return Ok(()),
            },
        };
        group.delete(self.provider.storage()).map_err(code)?;
        Ok(())
    }

    /// Ferme le moteur : l'état est déjà sur disque (écriture continue).
    pub fn close(self) {
        drop(self.groups);
        drop(self.meta);
        drop(self.provider);
    }
}
