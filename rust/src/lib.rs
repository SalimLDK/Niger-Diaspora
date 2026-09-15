//! Spike jetable (phase 1 du plan MLS) : vérifier qu'OpenMLS 0.9 tient le
//! parcours complet sur un stockage SQLite, avant d'y brancher Flutter Rust
//! Bridge. Rien ici n'est du code de production.

pub mod engine;
pub mod provider;

pub use engine::{CommitOut, GroupSnapshot, MlsEngine, MlsError, Processed};

pub mod ffi;
