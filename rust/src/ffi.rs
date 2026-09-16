//! Interface C du moteur, pour l'extension de notification iOS.
//!
//! POURQUOI UNE SECONDE PORTE
//! L'application passe par Flutter Rust Bridge, c'est-à-dire par Dart. Une
//! Notification Service Extension iOS n'a pas de Dart : c'est un binaire
//! séparé, en Swift, sans moteur Flutter. Elle ne peut donc appeler le moteur
//! que par une ABI C. Android n'a pas ce problème — là-bas l'aperçu est
//! reconstruit par un isolate Dart, qui a le pont.
//!
//! LE CONTRAT, ET POURQUOI IL EST FAIT AINSI
//! **L'appelant fournit le tampon de sortie.** Rien n'est alloué ici qui
//! devrait être libéré là-bas : pas de `*mut c_char` à rendre, pas de fonction
//! `free` jumelle à ne pas oublier, pas de question de propriété entre deux
//! langages et deux allocateurs. Swift passe un `[UInt8]`, lit combien d'octets
//! ont été écrits, et c'est tout.
//!
//! Le clair d'un message tient largement dans quelques kilo-octets — le
//! transport plafonne d'ailleurs le ciphertext du push à 2500 octets. Un
//! tampon trop court n'est pas une erreur silencieuse : la fonction rend
//! [`CODE_TAMPON_TROP_PETIT`] et pose dans `ecrits` la taille qu'il aurait
//! fallu.
//!
//! CE QU'ELLE NE FAIT PAS
//! Elle ne fait pas avancer l'état. `preview_without_state` travaille sur une
//! copie jetable (`VACUUM INTO`) : le cliquet de la base qui fait foi n'est
//! jamais touché, sans quoi l'application, en traitant ensuite le même
//! message, ne pourrait plus le lire. Un seul écrivain de l'état MLS.

use std::ffi::CStr;
use std::os::raw::{c_char, c_int};
use std::path::Path;
use std::slice;

use crate::engine::{preview_without_state, MlsError};

/// Déchiffrement réussi ; `ecrits` porte la longueur de la charge utile.
pub const CODE_OK: c_int = 0;
/// Un pointeur obligatoire était nul.
pub const CODE_ARGUMENT_NUL: c_int = -1;
/// Une chaîne n'était pas de l'UTF-8 valide.
pub const CODE_UTF8_INVALIDE: c_int = -2;
/// Le tampon de sortie est trop court ; `ecrits` porte la taille nécessaire.
pub const CODE_TAMPON_TROP_PETIT: c_int = -3;
/// Le moteur a refusé : groupe inconnu, AAD qui ne correspond pas, message
/// déjà consommé, base illisible. L'appelant retombe sur l'aperçu générique.
pub const CODE_ECHEC_MOTEUR: c_int = -4;

/// Reconstruit la charge utile d'un message chiffré, sans toucher à l'état.
///
/// Ce qui sort est le **payload** du plan MLS § 6.2 — du JSON portant le type,
/// le corps, la citation, les mentions, le minuteur — et non un texte
/// affichable. L'appelant en tire un résumé (`MlsPontNatif.resume` côté Swift,
/// `MlsNotificationPreview.resume` côté Dart) : poser ce JSON tel quel dans une
/// notification exposerait tout le contenu sur l'écran verrouillé.
///
/// # Sécurité
///
/// Tous les pointeurs doivent être valides pour la durée de l'appel. Les
/// quatre premiers sont des chaînes C terminées par zéro. `message` et `aad`
/// pointent vers `message_len` et `aad_len` octets lisibles. `sortie` pointe
/// vers `sortie_taille` octets inscriptibles. `ecrits` est écrit dans tous les
/// cas où la fonction rend `CODE_OK` ou `CODE_TAMPON_TROP_PETIT`.
#[no_mangle]
pub unsafe extern "C" fn diaspo_mls_apercu(
    db_path: *const c_char,
    user_id: *const c_char,
    device_id: *const c_char,
    conversation_id: *const c_char,
    message: *const u8,
    message_len: usize,
    aad: *const u8,
    aad_len: usize,
    sortie: *mut u8,
    sortie_taille: usize,
    ecrits: *mut usize,
) -> c_int {
    if db_path.is_null()
        || user_id.is_null()
        || device_id.is_null()
        || conversation_id.is_null()
        || message.is_null()
        || sortie.is_null()
        || ecrits.is_null()
    {
        return CODE_ARGUMENT_NUL;
    }
    // `aad` peut être vide, mais alors sa longueur doit l'être aussi.
    if aad.is_null() && aad_len != 0 {
        return CODE_ARGUMENT_NUL;
    }

    let lire = |p: *const c_char| CStr::from_ptr(p).to_str().ok();
    let (Some(chemin), Some(uid), Some(did), Some(cid)) = (
        lire(db_path),
        lire(user_id),
        lire(device_id),
        lire(conversation_id),
    ) else {
        return CODE_UTF8_INVALIDE;
    };

    let corps = slice::from_raw_parts(message, message_len);
    let etiquette = if aad_len == 0 {
        &[][..]
    } else {
        slice::from_raw_parts(aad, aad_len)
    };

    let clair = match preview_without_state(Path::new(chemin), uid, did, cid, corps, etiquette) {
        Ok(v) => v,
        Err(e) => return code_de(&e),
    };

    *ecrits = clair.len();
    if clair.len() > sortie_taille {
        // On dit la taille qu'il aurait fallu : l'appelant peut réessayer.
        return CODE_TAMPON_TROP_PETIT;
    }
    std::ptr::copy_nonoverlapping(clair.as_ptr(), sortie, clair.len());
    CODE_OK
}

/// Un seul code d'échec côté moteur, délibérément.
///
/// L'extension n'a qu'une décision à prendre : afficher le clair, ou laisser
/// le repli générique. Distinguer « groupe inconnu » de « AAD qui ne
/// correspond pas » ne changerait rien à ce qu'elle fait, et exposerait dans
/// une notification des détails sur l'état cryptographique. Le diagnostic fin
/// vit côté application, dans `mls_diagnostics`.
fn code_de(_e: &MlsError) -> c_int {
    CODE_ECHEC_MOTEUR
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    fn c(s: &str) -> CString {
        CString::new(s).unwrap()
    }

    #[test]
    fn un_pointeur_nul_est_refuse_sans_planter() {
        let mut ecrits = 0usize;
        let mut sortie = [0u8; 8];
        let code = unsafe {
            diaspo_mls_apercu(
                std::ptr::null(),
                c("u").as_ptr(),
                c("d").as_ptr(),
                c("cv").as_ptr(),
                [1u8].as_ptr(),
                1,
                std::ptr::null(),
                0,
                sortie.as_mut_ptr(),
                sortie.len(),
                &mut ecrits,
            )
        };
        assert_eq!(code, CODE_ARGUMENT_NUL);
    }

    #[test]
    fn un_aad_nul_avec_une_longueur_est_refuse() {
        // Le cas qui ferait lire n'importe où : longueur non nulle, pointeur
        // nul. Il doit être attrapé AVANT `from_raw_parts`.
        let mut ecrits = 0usize;
        let mut sortie = [0u8; 8];
        let code = unsafe {
            diaspo_mls_apercu(
                c("/x/y.sqlite").as_ptr(),
                c("u").as_ptr(),
                c("d").as_ptr(),
                c("cv").as_ptr(),
                [1u8].as_ptr(),
                1,
                std::ptr::null(),
                16,
                sortie.as_mut_ptr(),
                sortie.len(),
                &mut ecrits,
            )
        };
        assert_eq!(code, CODE_ARGUMENT_NUL);
    }

    #[test]
    fn une_base_absente_rend_un_echec_moteur_pas_un_plantage() {
        let dossier = std::env::temp_dir().join(format!("apercu-ffi-{}", std::process::id()));
        let _ = std::fs::create_dir_all(&dossier);
        let base = dossier.join("absente.sqlite");
        let mut ecrits = 0usize;
        let mut sortie = [0u8; 64];
        let code = unsafe {
            diaspo_mls_apercu(
                c(base.to_str().unwrap()).as_ptr(),
                c("u").as_ptr(),
                c("d").as_ptr(),
                c("cv").as_ptr(),
                [1u8, 2, 3].as_ptr(),
                3,
                [0u8; 0].as_ptr(),
                0,
                sortie.as_mut_ptr(),
                sortie.len(),
                &mut ecrits,
            )
        };
        assert_eq!(code, CODE_ECHEC_MOTEUR);
        let _ = std::fs::remove_dir_all(&dossier);
    }
}
