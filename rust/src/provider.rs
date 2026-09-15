//! Fournisseur OpenMLS du spike : crypto RustCrypto + stockage SQLite.
//!
//! `OpenMlsRustCrypto` embarque un stockage en mémoire ; on le remplace par
//! `openmls_sqlite_storage`, parce que c'est l'état MLS persistant qui fait
//! l'objet du spike (réouverture à froid, isolate background, NSE iOS).

use std::path::Path;

use openmls_rust_crypto::RustCrypto;
use openmls_sqlite_storage::{Codec, SqliteStorageProvider};
use openmls_traits::OpenMlsProvider;
use rusqlite::Connection;

/// Sérialisation JSON de l'état MLS dans SQLite. Le format n'a pas
/// d'importance pour le spike ; CBOR ou bincode iraient aussi.
#[derive(Default)]
pub struct JsonCodec;

impl Codec for JsonCodec {
    type Error = serde_json::Error;

    fn to_vec<T: serde::Serialize>(value: &T) -> Result<Vec<u8>, Self::Error> {
        serde_json::to_vec(value)
    }

    fn from_slice<T: serde::de::DeserializeOwned>(slice: &[u8]) -> Result<T, Self::Error> {
        serde_json::from_slice(slice)
    }
}

pub type Storage = SqliteStorageProvider<JsonCodec, Connection>;

pub struct DiaspoProvider {
    crypto: RustCrypto,
    storage: Storage,
}

impl DiaspoProvider {
    /// Ouvre (ou crée) la base SQLite de l'état MLS et applique les
    /// migrations du fournisseur de stockage.
    pub fn open(db_path: &Path) -> Result<Self, ProviderError> {
        let connection = Connection::open(db_path)?;
        // Durabilité raisonnable pour un état de cliquet : une écriture
        // perdue rend la conversation illisible.
        connection.pragma_update(None, "journal_mode", "WAL")?;
        connection.pragma_update(None, "synchronous", "FULL")?;
        let mut storage = SqliteStorageProvider::<JsonCodec, _>::new(connection);
        storage
            .run_migrations()
            .map_err(|e| ProviderError::Migrations(format!("{e:?}")))?;
        Ok(Self {
            crypto: RustCrypto::default(),
            storage,
        })
    }
}

impl OpenMlsProvider for DiaspoProvider {
    type CryptoProvider = RustCrypto;
    type RandProvider = RustCrypto;
    type StorageProvider = Storage;

    fn storage(&self) -> &Self::StorageProvider {
        &self.storage
    }

    fn crypto(&self) -> &Self::CryptoProvider {
        &self.crypto
    }

    fn rand(&self) -> &Self::RandProvider {
        &self.crypto
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ProviderError {
    #[error("sqlite")]
    Sqlite(#[from] rusqlite::Error),
    #[error("migrations")]
    Migrations(String),
}
