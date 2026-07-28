---
name: project_pinned_banner_telegram
description: Le bandeau épinglé doit rester une ligne fine style Telegram toujours visible (jamais masqué au clavier) ; épingles orphelines si message supprimé
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6e290746-aead-4381-af41-4a0c8b9decff
  modified: 2026-07-28T16:35:59.193Z
---

Le bandeau des messages épinglés (`group_pinned_banner.dart`, affiché dans `conversation_screen.dart`) doit suivre le modèle **Telegram** : une **seule ligne fine** (~44 px) fixée sous l'en-tête, avec barre d'accent colorée, libellé + aperçu du message réel, compteur `i/n` quand plusieurs épingles (tap = défiler).

Règles ajoutées le 2026-07-17 (demande explicite) :
- **Pas de croix de désépinglage** dans le bandeau (paramètre `canUnpin` supprimé de bout en bout).
- Le bandeau ne s'affiche **que si quelque chose est réellement épinglé** : si le message épinglé est introuvable ou supprimé (`deletedForEveryone`), ou pas encore chargé, retourner `SizedBox.shrink()` — jamais de libellé de repli type « Appuyez pour voir ».
- Le widget **porte sa propre marge** (`Padding` interne dans `_row`) : aucun `Padding` externe côté appelant, sinon un espace vide subsiste quand rien n'est épinglé.

**Why:** l'utilisateur a explicitement rejeté (2026-07-17) la solution consistant à masquer le bandeau quand le clavier s'ouvre — « masquer n'est pas la solution, je le veux comme dans Telegram ». Il a fourni une capture Telegram en référence (bandeau « Pinned Message #7 »).

**How to apply:** garder la hauteur fixe mono-ligne — c'est ce qui élimine l'overflow paysage+clavier sans masquer quoi que ce soit. Ne jamais réintroduire de condition `viewInsets.bottom == 0` autour du bandeau. Les cartes empilées (2 épingles visibles + compteur) sont à éviter : Telegram n'en montre qu'une. Ne pas réintroduire de croix ni de libellé de repli.

**Épingles orphelines** : `deleteMessageForEveryone` (message_supabase_datasource.dart) fait un soft-delete ; sans nettoyage en cascade de `group_pinned_items` (item_type='message', item_id=messageId), le bandeau garde une entrée fantôme « Appuyez pour voir » vers un message inexistant. Le cascade a été ajouté, mais les épingles orphelines antérieures subsistent (retirables via la croix).

**Corrections 2026-07-28 (5 bugs du bandeau épinglé) :**
1. Texte chiffré brut affiché → `MessageSupabaseDataSource.getMessageById` ne déchiffrait pas ; il passe désormais par `_msgFromRowAsync` (même déchiffrement E2EE/AES que la pagination).
2. Chiffré `iv:ciphertext` base64 non détecté par le garde-fou (`🔐`/`gcm:` seulement) → ajout `_kCiphertextPattern` (regex base64:base64) ; on masque UNIQUEMENT le chiffré brut, on affiche le contenu réel (y compris le repli « 🔐 Message chiffré »).
3. **Ne s'affiche pas à l'épinglage** → le stream Supabase `group_pinned_items` ne reçoit pas toujours l'insert en realtime ; `_pinMessage`/`_unpinMessage` (conversation_screen) appellent `_refreshPinnedBanner()` = `ref.invalidate` du provider après succès.
4. **Clignote / disparaît** (rebuild clavier, re-souscription `ensureAuthenticated`) → `_GroupPinnedBannerState` garde `_lastItems` (dernière liste connue) : `if (itemsAsync.hasValue) _lastItems = value; items = valueOrNull ?? _lastItems`.
5. **« De tout type »** : les bulles média (`OptimizedImageBubble`, `VideoBubble`) captaient l'appui long avec leur propre menu Enregistrer/Partager → **pas d'Épingler**. Ajout d'un param `onLongPress` préféré au menu média ; `MessageBubble` y passe `_onLongPress` (menu complet) pour image/vidéo/sticker ; « Enregistrer » ajouté au menu complet pour image/vidéo. Le bandeau libelle chaque type (`_messagePreview` : 📅 Événement / 🛍️ Produit / 🔗 Publication / média / texte). doc/location/audio_file ne captaient pas l'appui long (remontaient déjà au menu complet).

Builds arm64 OK (compilateur valide) ; `flutter analyze` complet NON relancé (≈1h40 dans cet env). Vérif device partielle : le déchiffrement réel ne se voit pas (clés E2EE perdues sur le build debug réinstallé → bulles « 🔐 Message chiffré »).

Voir [[project_polls_events_scope]].
