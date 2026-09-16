//! Spike jetable (phase 1 du plan MLS) : vérifier qu'OpenMLS 0.9 tient le
//! parcours complet sur un stockage SQLite, avant d'y brancher Flutter Rust
//! Bridge. Rien ici n'est du code de production.

pub mod api;
pub mod engine;
/// Interface C, pour l'extension de notification iOS (pas de Dart la-bas).
pub mod ffi;
mod frb_generated;
pub mod provider;

pub use engine::{preview_without_state, CommitOut, GroupSnapshot, MlsEngine, MlsError, Processed};

