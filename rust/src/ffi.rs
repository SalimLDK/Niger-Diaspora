//! Point d'entrée C minimal, pour deux raisons de spike :
//!
//! 1. sans symbole exporté, l'éditeur de liens élague TOUT le crate et la
//!    `.so` ne pèse rien — la mesure de poids serait un mensonge ;
//! 2. c'est ce qu'un `adb shell` ou un `dart:ffi` jetable peut appeler pour
//!    chronométrer un parcours à froid sur l'appareil, avant FRB.
//!
//! FRB générera sa propre surface ; celle-ci disparaîtra avec le spike.

use std::ffi::CStr;
use std::os::raw::c_char;
use std::path::Path;
use std::time::Instant;

use crate::{MlsEngine, Processed};

/// Joue le parcours nominal (Alice crée, ajoute Bob, message aller-retour)
/// dans `db_dir`, et rend la durée totale en microsecondes, ou un code
/// négatif en cas d'échec.
///
/// # Safety
/// `db_dir` doit être une chaîne C valide, encodée en UTF-8.
#[no_mangle]
pub unsafe extern "C" fn diaspo_mls_spike_parcours(db_dir: *const c_char) -> i64 {
    if db_dir.is_null() {
        return -1;
    }
    let dir = match CStr::from_ptr(db_dir).to_str() {
        Ok(s) => Path::new(s),
        Err(_) => return -2,
    };
    let depart = Instant::now();
    let conv = "spike";
    let resultat = (|| -> Result<(), crate::MlsError> {
        let mut alice = MlsEngine::open(&dir.join("alice.sqlite"), "alice", "a1")?;
        let mut bob = MlsEngine::open(&dir.join("bob.sqlite"), "bob", "b1")?;
        alice.create_group(conv)?;
        let kp = bob.create_key_packages(1, false)?.remove(0);
        let out = alice.add_members(conv, &[kp])?;
        alice.merge_pending_commit(conv)?;
        bob.process_welcome(conv, out.welcome.as_deref().unwrap_or_default())?;
        let aad = b"dn-mls/1|spike|m1|a1|content";
        let ct = alice.encrypt(conv, b"spike", aad)?;
        match bob.process_incoming(conv, &ct, aad)? {
            Processed::Application(bytes) if bytes == b"spike" => Ok(()),
            _ => Err(crate::MlsError::NotApplicationMessage),
        }
    })();
    match resultat {
        Ok(()) => depart.elapsed().as_micros() as i64,
        Err(_) => -3,
    }
}

/// Réouvre une base existante et déchiffre un message : c'est le chemin
/// « notification en arrière-plan », celui dont le budget est < 2 s.
///
/// # Safety
/// Mêmes contraintes que [`diaspo_mls_spike_parcours`] ; `ct`/`ct_len`
/// décrivent un tampon lisible.
#[no_mangle]
pub unsafe extern "C" fn diaspo_mls_spike_reouverture(
    db_path: *const c_char,
    ct: *const u8,
    ct_len: usize,
) -> i64 {
    if db_path.is_null() || ct.is_null() {
        return -1;
    }
    let path = match CStr::from_ptr(db_path).to_str() {
        Ok(s) => Path::new(s),
        Err(_) => return -2,
    };
    let ciphertext = std::slice::from_raw_parts(ct, ct_len);
    let depart = Instant::now();
    let ok = MlsEngine::open(path, "bob", "b1")
        .and_then(|mut bob| bob.process_incoming("spike", ciphertext, b"dn-mls/1|spike|m2|a1|content"))
        .is_ok();
    if ok {
        depart.elapsed().as_micros() as i64
    } else {
        -3
    }
}
