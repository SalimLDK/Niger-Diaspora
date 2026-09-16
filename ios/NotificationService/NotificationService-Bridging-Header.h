//  En-tête de pont de la cible NotificationService.
//
//  L'extension est en Swift et le moteur en Rust : ce fichier est le seul
//  endroit où le symbole C devient visible du Swift. À renseigner dans
//  « Build Settings > Objective-C Bridging Header » de la cible
//  NotificationService (pas de celle du Runner).
//
//  ⚠️ Cette déclaration doit rester le miroir exact de `rust/src/ffi.rs`. Le
//  lieur ne vérifie que le nom du symbole, jamais les types : un paramètre en
//  trop ou un `usize` devenu `int` passerait la compilation et corromprait la
//  pile à l'exécution.

#ifndef NotificationService_Bridging_Header_h
#define NotificationService_Bridging_Header_h

#include <stddef.h>
#include <stdint.h>

/// Reconstruit le clair d'un message MLS sans faire avancer l'état.
///
/// Codes de retour (cf. `rust/src/ffi.rs`) :
///   0  succès, `ecrits` porte la longueur du clair ;
///  -1  un pointeur obligatoire était nul ;
///  -2  une chaîne n'était pas de l'UTF-8 valide ;
///  -3  `sortie_taille` trop petit, `ecrits` porte la taille nécessaire ;
///  -4  le moteur a refusé (groupe inconnu, AAD, message déjà consommé).
int diaspo_mls_apercu(const char *db_path,
                      const char *user_id,
                      const char *device_id,
                      const char *conversation_id,
                      const uint8_t *message,
                      size_t message_len,
                      const uint8_t *aad,
                      size_t aad_len,
                      uint8_t *sortie,
                      size_t sortie_taille,
                      size_t *ecrits);

#endif /* NotificationService_Bridging_Header_h */
