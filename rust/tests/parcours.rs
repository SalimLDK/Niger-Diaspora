//! Le banc du spike : Alice, Bob et Charlie, chacun sa base SQLite, reliés
//! par des octets — exactement ce que Supabase transportera.
//!
//! Chaque cas correspond à une ligne de la phase 3 du plan. Ce qui casse ici
//! casserait en production, en silence.

use std::path::PathBuf;

use diaspo_mls::{
    balayer_copies_orphelines, preview_without_state, MlsEngine, MlsError, Processed,
    AGE_COPIE_ORPHELINE,
};

fn base(nom: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("diaspo_mls_spike_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    dir.join(format!("{nom}.sqlite"))
}

fn aad(conv: &str, msg: &str, sender: &str) -> Vec<u8> {
    format!("dn-mls/1|{conv}|{msg}|{sender}|content").into_bytes()
}

/// AAD d'un commit : la conversation et l'epoch qu'il produit.
fn aad_commit(conv: &str, epoch: u64) -> Vec<u8> {
    format!("dn-mls/1|{conv}|commit|{epoch}").into_bytes()
}

/// Alice crée, ajoute Bob, les deux s'écrivent.
fn alice_et_bob(conv: &str) -> (MlsEngine, MlsEngine) {
    let mut alice = MlsEngine::open(&base(&format!("alice_{conv}")), "alice", "a1").unwrap();
    let mut bob = MlsEngine::open(&base(&format!("bob_{conv}")), "bob", "b1").unwrap();

    alice.create_group(conv).unwrap();
    let kp_bob = bob.create_key_packages(1, false).unwrap().remove(0);
    let out = alice.add_members(conv, &[kp_bob], &aad_commit(conv, 1)).unwrap();
    alice.merge_pending_commit(conv).unwrap();
    let snap = bob.process_welcome(conv, out.welcome.as_ref().unwrap()).unwrap();
    assert_eq!(snap.epoch, 1);
    assert_eq!(snap.members.len(), 2);
    (alice, bob)
}

/// Chaque feuille porte la clé de signature de SON appareil : c'est ce que
/// l'app compare au registre pour démasquer une feuille qui emprunte
/// l'identité d'un autre (le `BasicCredential` n'est qu'une chaîne).
#[test]
fn les_feuilles_portent_la_cle_de_leur_appareil() {
    let conv = "conv-cles-feuilles";
    let (mut alice, mut bob) = alice_et_bob(conv);
    let cle_alice = alice.public_signature_key().to_vec();
    let cle_bob = bob.public_signature_key().to_vec();
    assert_ne!(cle_alice, cle_bob);

    for snap in [alice.snapshot(conv).unwrap(), bob.snapshot(conv).unwrap()] {
        for m in &snap.members {
            let attendue = if m.identity.starts_with(b"alice:") { &cle_alice } else { &cle_bob };
            assert_eq!(&m.signature_key, attendue);
        }
    }
}

#[test]
fn parcours_nominal_1_a_1() {
    let conv = "conv-nominal";
    let (mut alice, mut bob) = alice_et_bob(conv);

    let aad1 = aad(conv, "m1", "a1");
    let ct = alice.encrypt(conv, b"Salut Bob", &aad1).unwrap();
    // Taille réelle d'un ciphertext : elle décide si le push peut le porter
    // (plafond FCM 4 Ko, marge prise à 2500 o pour le reste du payload).
    eprintln!("TAILLE ciphertext {} o pour {} o de clair", ct.len(), b"Salut Bob".len());
    assert!(!ct.windows(9).any(|w| w == b"Salut Bob"), "le ciphertext contient le clair");

    match bob.process_incoming(conv, &ct, &aad1).unwrap() {
        Processed::Application { clair: bytes, .. } => assert_eq!(bytes, b"Salut Bob"),
        _ => panic!("attendu un message applicatif"),
    }

    let aad2 = aad(conv, "m2", "b1");
    let ct2 = bob.encrypt(conv, b"Salut Alice", &aad2).unwrap();
    match alice.process_incoming(conv, &ct2, &aad2).unwrap() {
        Processed::Application { clair: bytes, .. } => assert_eq!(bytes, b"Salut Alice"),
        _ => panic!("attendu un message applicatif"),
    }
}

#[test]
fn aad_deplace_est_refuse() {
    let conv = "conv-aad";
    let (mut alice, mut bob) = alice_et_bob(conv);
    let ct = alice.encrypt(conv, b"secret", &aad(conv, "m1", "a1")).unwrap();
    // Même ciphertext, présenté sous un autre id de message.
    let err = bob.process_incoming(conv, &ct, &aad(conv, "m2", "a1")).unwrap_err();
    assert!(matches!(err, MlsError::AadMismatch), "{err:?}");
}

#[test]
fn message_recu_deux_fois_est_refuse() {
    let conv = "conv-doublon";
    let (mut alice, mut bob) = alice_et_bob(conv);
    let a = aad(conv, "m1", "a1");
    let ct = alice.encrypt(conv, b"une fois", &a).unwrap();
    assert!(bob.process_incoming(conv, &ct, &a).is_ok());
    let rejeu = bob.process_incoming(conv, &ct, &a);
    assert!(rejeu.is_err(), "un rejeu doit échouer, pas rendre le clair");
}

#[test]
fn message_d_un_epoch_passe_reste_lisible() {
    let conv = "conv-epoch";
    let (mut alice, mut bob) = alice_et_bob(conv);

    // Alice émet à l'epoch 1, puis commite (retrait de personne : on ajoute
    // Charlie pour changer d'epoch), et Bob reçoit le commit AVANT le message.
    let a = aad(conv, "m1", "a1");
    let ct_avant = alice.encrypt(conv, "émis avant le commit".as_bytes(), &a).unwrap();

    let mut charlie = MlsEngine::open(&base("charlie_epoch"), "charlie", "c1").unwrap();
    let kp = charlie.create_key_packages(1, false).unwrap().remove(0);
    let out = alice.add_members(conv, &[kp], &aad_commit(conv, 2)).unwrap();
    alice.merge_pending_commit(conv).unwrap();
    // Le commit porte son propre AAD, posé par le moteur (piège du spike :
    // OpenMLS vide l'AAD après chaque message sortant).
    match bob.process_incoming(conv, &out.commit, &aad_commit(conv, 2)).unwrap() {
        Processed::Commit(snap) => assert_eq!(snap.epoch, 2),
        _ => panic!("attendu un commit"),
    }

    match bob.process_incoming(conv, &ct_avant, &a).unwrap() {
        Processed::Application { clair: bytes, .. } => assert_eq!(bytes, "émis avant le commit".as_bytes()),
        _ => panic!("attendu un message applicatif"),
    }
}

#[test]
fn membre_retire_ne_lit_plus() {
    let conv = "conv-retrait";
    let (mut alice, mut bob) = alice_et_bob(conv);
    let leaf_bob = alice
        .snapshot(conv)
        .unwrap()
        .members
        .into_iter()
        .find(|m| m.identity.starts_with(b"bob:b1:"))
        .unwrap()
        .leaf_index;
    let out = alice.remove_members(conv, &[leaf_bob], &aad_commit(conv, 2)).unwrap();
    alice.merge_pending_commit(conv).unwrap();
    let a = aad(conv, "m-apres", "a1");
    // Bob traite le commit qui le retire : le groupe devient inactif pour lui.
    let _ = bob.process_incoming(conv, &out.commit, &aad_commit(conv, 2));

    let ct = alice.encrypt(conv, "après ton départ".as_bytes(), &a).unwrap();
    assert!(bob.process_incoming(conv, &ct, &a).is_err());
}

#[test]
fn moteur_ferme_et_rouvert_conserve_le_groupe() {
    let conv = "conv-reouverture";
    let (alice, mut bob) = alice_et_bob(conv);
    let chemin = base(&format!("alice_{conv}"));
    alice.close();

    // Nouveau moteur sur la même base : même identité, même groupe.
    let mut alice2 = MlsEngine::open(&chemin, "alice", "a1").unwrap();
    assert!(alice2.identity().starts_with(b"alice:a1:"));
    let snap = alice2.snapshot(conv).unwrap();
    assert_eq!(snap.epoch, 1);

    let a = aad(conv, "m-apres", "a1");
    let ct = alice2.encrypt(conv, "toujours là".as_bytes(), &a).unwrap();
    match bob.process_incoming(conv, &ct, &a).unwrap() {
        Processed::Application { clair: bytes, .. } => assert_eq!(bytes, "toujours là".as_bytes()),
        _ => panic!("attendu un message applicatif"),
    }
}

#[test]
fn jointure_externe_par_group_info() {
    let conv = "conv-externe";
    let (mut alice, mut bob) = alice_et_bob(conv);
    let group_info = alice.export_group_info(conv).unwrap();

    let mut charlie = MlsEngine::open(&base("charlie_externe"), "charlie", "c1").unwrap();
    let a_join = aad(conv, "join", "c1");
    let out = charlie.join_by_external_commit(conv, &group_info, &a_join).unwrap();
    assert_eq!(charlie.snapshot(conv).unwrap().epoch, 2);

    // Les membres existants traitent le commit externe (en clair, forcément).
    match alice.process_incoming(conv, &out.commit, &a_join).unwrap() {
        Processed::Commit(snap) => {
            assert_eq!(snap.epoch, 2);
            assert!(snap.members.iter().any(|m| m.identity.starts_with(b"charlie:c1:")));
        }
        _ => panic!("attendu un commit"),
    }
    match bob.process_incoming(conv, &out.commit, &a_join).unwrap() {
        Processed::Commit(snap) => assert_eq!(snap.epoch, 2),
        _ => panic!("attendu un commit"),
    }

    let a = aad(conv, "m1", "c1");
    let ct = charlie.encrypt(conv, "bonjour à tous".as_bytes(), &a).unwrap();
    match alice.process_incoming(conv, &ct, &a).unwrap() {
        Processed::Application { clair: bytes, .. } => assert_eq!(bytes, "bonjour à tous".as_bytes()),
        _ => panic!("attendu un message applicatif"),
    }
}

#[test]
fn commit_perdant_se_jette_proprement() {
    let conv = "conv-concurrence";
    let (mut alice, mut bob) = alice_et_bob(conv);
    let mut charlie = MlsEngine::open(&base("charlie_conc"), "charlie", "c1").unwrap();
    let mut dora = MlsEngine::open(&base("dora_conc"), "dora", "d1").unwrap();

    // Alice et Bob commitent tous deux pour l'epoch 2, chacun un ajout.
    let kp_c = charlie.create_key_packages(1, false).unwrap().remove(0);
    let kp_d = dora.create_key_packages(1, false).unwrap().remove(0);
    let out_alice = alice.add_members(conv, &[kp_c], &aad_commit(conv, 2)).unwrap();
    let _out_bob = bob.add_members(conv, &[kp_d], &aad_commit(conv, 2)).unwrap();

    // Le serveur a pris celui d'Alice (23505 pour Bob) : Bob jette le sien,
    // traite celui d'Alice, et recommencera.
    alice.merge_pending_commit(conv).unwrap();
    bob.clear_pending_commit(conv).unwrap();
    match bob.process_incoming(conv, &out_alice.commit, &aad_commit(conv, 2)).unwrap() {
        Processed::Commit(snap) => assert_eq!(snap.epoch, 2),
        _ => panic!("attendu un commit"),
    }
    assert_eq!(bob.snapshot(conv).unwrap().members.len(), 3);
}

/// Ordre de grandeur, sur le poste : réouverture d'une base + déchiffrement
/// d'un message. Sur l'appareil (SM A515F), c'est le budget « notification
/// en arrière-plan » (< 2 s) qu'il faudra mesurer pour de vrai.
#[test]
fn chronometre_reouverture_a_froid() {
    let conv = "conv-chrono";
    let (mut alice, bob) = alice_et_bob(conv);
    let chemin_bob = base(&format!("bob_{conv}"));
    bob.close();
    let a = aad(conv, "m1", "a1");
    let ct = alice.encrypt(conv, b"chrono", &a).unwrap();

    let depart = std::time::Instant::now();
    let mut bob2 = MlsEngine::open(&chemin_bob, "bob", "b1").unwrap();
    let ouverture = depart.elapsed();
    let dechiffre = bob2.process_incoming(conv, &ct, &a).unwrap();
    let total = depart.elapsed();
    assert!(matches!(dechiffre, Processed::Application { clair: ref b, .. } if b == b"chrono"));
    eprintln!(
        "CHRONO ouverture {:?} — ouverture + déchiffrement {:?}",
        ouverture, total
    );
}

/// L'aperçu de notification ne doit RIEN consommer.
///
/// C'est le cas qui garde le piège du § 8 : si l'isolate de notification
/// faisait avancer le cliquet, l'application ne pourrait plus lire le message
/// qu'elle vient d'annoncer, et la conversation deviendrait illisible sans
/// qu'aucune erreur ne le dise.
#[test]
fn l_apercu_ne_consomme_pas_le_cliquet() {
    let conv = "conv-apercu";
    let (mut alice, bob) = alice_et_bob(conv);
    let chemin_bob = base(&format!("bob_{conv}"));
    // L'app « se met en veille » : plus personne ne tient la base.
    bob.close();

    let a = aad(conv, "m1", "a1");
    let ct = alice.encrypt(conv, "message qui arrive".as_bytes(), &a).unwrap();

    // 1. L'isolate de notification déchiffre pour l'aperçu.
    let apercu = preview_without_state(&chemin_bob, "bob", "b1", conv, &ct, &a).unwrap();
    assert_eq!(apercu, "message qui arrive".as_bytes());

    // 2. Deux fois : un même push peut être livré en double.
    let encore = preview_without_state(&chemin_bob, "bob", "b1", conv, &ct, &a).unwrap();
    assert_eq!(encore, "message qui arrive".as_bytes());

    // 3. L'application se réveille et traite le MÊME message : elle doit
    //    encore pouvoir le lire. C'est tout l'enjeu.
    let mut bob2 = MlsEngine::open(&chemin_bob, "bob", "b1").unwrap();
    match bob2.process_incoming(conv, &ct, &a).unwrap() {
        Processed::Application { clair, .. } => assert_eq!(clair, "message qui arrive".as_bytes()),
        _ => panic!("attendu un message applicatif"),
    }

    // 4. Et la suite de la conversation continue de fonctionner.
    let a2 = aad(conv, "m2", "a1");
    let ct2 = alice.encrypt(conv, "et la suite".as_bytes(), &a2).unwrap();
    match bob2.process_incoming(conv, &ct2, &a2).unwrap() {
        Processed::Application { clair, .. } => assert_eq!(clair, "et la suite".as_bytes()),
        _ => panic!("attendu un message applicatif"),
    }

    // 5. Aucune copie jetable ne traîne à côté de la base.
    let dossier = chemin_bob.parent().unwrap();
    let restes: Vec<_> = std::fs::read_dir(dossier)
        .unwrap()
        .filter_map(|e| e.ok())
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|nom| nom.contains("apercu-"))
        .collect();
    assert!(restes.is_empty(), "copies jetables laissées derrière : {restes:?}");
}

/// L'émetteur rendu est celui que MLS a authentifié, quoi que dise l'AAD :
/// c'est sur lui que l'app confronte l'auteur inscrit par le serveur.
#[test]
fn l_emetteur_est_celui_que_mls_authentifie() {
    let conv = "conv-emetteur";
    let (mut alice, mut bob) = alice_et_bob(conv);
    // Alice déclare dans son AAD l'appareil de Bob : l'AAD est à son choix.
    let aad_mensonger = aad(conv, "m-usurpe", "b1");
    let chiffre = alice.encrypt(conv, b"je suis Bob", &aad_mensonger).unwrap();
    match bob.process_incoming(conv, &chiffre, &aad_mensonger).unwrap() {
        Processed::Application { emetteur, .. } => {
            assert!(emetteur.starts_with(b"alice:"), "émetteur : {:?}", String::from_utf8_lossy(&emetteur));
        }
        autre => panic!("attendu un message applicatif, obtenu {autre:?}"),
    }
}

/// Une copie d'aperçu orpheline — processus tué entre `VACUUM INTO` et le
/// nettoyage — est une base complète figée à un epoch passé : elle garde des
/// secrets que le cliquet devait effacer. Elle est balayée dès qu'elle a
/// passé l'âge d'un aperçu en cours ; une copie fraîche (un aperçu qui tourne
/// dans l'autre isolate) est laissée.
#[test]
fn les_copies_d_apercu_orphelines_sont_balayees() {
    let chemin = base("balayage");
    let dossier = chemin.parent().unwrap();
    let tronc = chemin.file_stem().unwrap().to_string_lossy().into_owned();
    let vieille = dossier.join(format!("{tronc}.apercu-1-1.sqlite"));
    let vieux_wal = dossier.join(format!("{tronc}.apercu-1-1.sqlite-wal"));
    let fraiche = dossier.join(format!("{tronc}.apercu-2-2.sqlite"));
    let voisine = dossier.join("autre.apercu-3-3.sqlite");
    for f in [&vieille, &vieux_wal, &fraiche, &voisine] {
        std::fs::write(f, b"secrets").unwrap();
    }
    let il_y_a_longtemps = std::time::SystemTime::now() - AGE_COPIE_ORPHELINE * 2;
    for f in [&vieille, &vieux_wal, &voisine] {
        std::fs::File::options().write(true).open(f).unwrap().set_modified(il_y_a_longtemps).unwrap();
    }

    // L'ouverture du moteur balaie.
    let _moteur = MlsEngine::open(&chemin, "zoe", "z1").unwrap();

    assert!(!vieille.exists(), "la copie orpheline doit partir");
    assert!(!vieux_wal.exists(), "son journal aussi");
    assert!(fraiche.exists(), "un aperçu en cours ne doit pas perdre sa copie");
    assert!(voisine.exists(), "la copie d'une autre base n'est pas la nôtre");

    balayer_copies_orphelines(&chemin, std::time::Duration::ZERO);
    assert!(!fraiche.exists());
    let _ = std::fs::remove_file(&voisine);
}
