# Demande de position aux postes diplomatiques

> **Mise à jour du 2026-09-08 — n'envoyez plus que deux de ces onze messages.**
>
> La Geocoding API de Google a été activée sur le projet dans la journée, et
> **neuf des onze postes y sont trouvables** — à condition de les chercher par
> leur nom dans la langue du pays d'accueil (Le Caire ne répond qu'à l'arabe,
> La Havane qu'à l'espagnol). Leurs coordonnées sont en base depuis la
> migration `20260908150000_coordonnees_postes_google.sql`, et trois d'entre
> elles recoupent l'adresse publiée par le ministère : Le Caire (101 Al Haram
> = avenue des Pyramides), Rabat (Av. Al Haour) et Dubaï (Abu Hail = « Abau
> Hain Street »).
>
> **Restent à écrire : Djeddah (§2) et Khartoum (§5).** Google ne connaît
> aucun lieu d'ambassade à Khartoum, et le seul résultat de Djeddah, à 22 km
> au nord du centre, n'est pas typé `embassy` — trop faible pour être écrit.
>
> **Deux questions se sont ouvertes en revanche, qui ne sont pas dans cette
> liste** et mériteraient un message du même genre :
> - **Copenhague** : OpenStreetMap place l'ambassade Rosbækvej/Østerbro,
>   l'annuaire publie « Niels Juels Gade 5 » — 5,1 km d'écart, rien pour
>   départager.
> - **Abuja** : le pin a été déplacé de Diplomatic Drive à Maitama, où
>   l'annuaire et Google se rejoignent. Une confirmation ne ferait pas de mal.
>
> Les messages ci-dessous restent valables tels quels pour ces cas : seule la
> liste des destinataires change.


Onze postes de l'annuaire n'ont pas de coordonnées géographiques, et **aucune
source publique ne les contient** : OpenStreetMap n'a aucun nœud pour dix
d'entre eux, et le géocodage de leur adresse postale rend un hôtel, un arrêt
de bus ou un centroïde de quartier — jamais la chancellerie. Le constat détaillé
est dans `TESTS_APPAREIL_A_FAIRE.md`.

Il ne reste qu'une voie : **demander la position aux postes eux-mêmes**. Ce
fichier contient les onze messages, prêts à envoyer.

## Avant d'envoyer — trois réserves

- **La Havane est injoignable.** Le ministère publie `--` dans les quatre
  champs : ni téléphone, ni adresse, ni e-mail. Son message doit passer par
  le ministère à Niamey, pas par le poste.
- **Doha et Pékin** répondent sur une boîte au nom d'une personne
  (`abdoulbonz@`, `middahmaimouna@`), pas du poste. Elles peuvent être
  périmées depuis une mutation.
- Une adresse Yahoo ne prouve pas qu'elle soit relevée. Prévoir que plusieurs
  restent sans réponse, et relancer par téléphone les postes qui en publient un.

## Ce qu'on demande, et pourquoi c'est court

Chaque message tient en quelques lignes et pose **une** question principale :
où se trouve le bâtiment. Une demande courte obtient une réponse ; une demande
qui liste dix champs à confirmer finit sans réponse du tout.

La façon la plus simple pour eux de répondre — et celle que le message
propose — est un **lien Google Maps** : ouvrir Maps, poser un repère sur le
bâtiment, « Partager », coller le lien. Pas besoin de savoir ce qu'est une
latitude.

Les horaires d'ouverture sont demandés en second, en une phrase, parce qu'on
ne les a pour aucun des 32 postes et qu'un second courrier coûterait plus cher
que cette ligne.

## Signature à compléter

Remplacer `[VOTRE NOM]` et `[VOTRE FONCTION]` dans chaque message. Ne pas se
présenter comme un service officiel : Diaspo Niger est une application
indépendante, et le dire évite un malentendu qui coûterait la réponse.

---

## 1. Ambassade du Niger en Éthiopie — Addis-Abeba

**À :** ambnigeradiss@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse que publie le ministère des Affaires étrangères pour votre
> ambassade est : *Kirkos Sub-city, Kebele 02/03, House No 0547, P.O. Box 5791*.
> Elle désigne un quartier, mais aucune source cartographique ne permet d'en
> déduire l'emplacement exact de la chancellerie — l'application ne peut donc
> pas vous placer sur une carte.
>
> **Pourriez-vous m'indiquer la position de vos bureaux ?** Le plus simple est
> d'ouvrir Google Maps, de poser un repère sur le bâtiment, puis « Partager »
> et de me renvoyer le lien. Une adresse de rue précise conviendrait aussi.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public** compléteraient
> utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Excellence, Madame,
> Monsieur, l'expression de ma haute considération.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 2. Consulat général du Niger à Djeddah

**À :** Djeddah_consulatgnralniger@yahoo.fr
**Objet :** Localisation du consulat pour l'application Diaspo Niger

> Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> La seule adresse publiée pour votre consulat est une boîte postale
> (*B.P. 1709 Djeddah 21441*). Une boîte postale ne désigne aucun bâtiment :
> l'application ne peut pas vous placer sur une carte, et nos compatriotes à
> Djeddah ne savent pas où se présenter.
>
> **Pourriez-vous m'indiquer l'adresse physique et la position de vos
> bureaux ?** Le plus simple est d'ouvrir Google Maps, de poser un repère sur
> le bâtiment, puis « Partager » et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Madame, Monsieur,
> l'expression de ma considération distinguée.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 3. Ambassade du Niger au Qatar — Doha

**À :** abdoulbonz@yahoo.fr
**Objet :** Coordonnées de l'ambassade pour l'application Diaspo Niger

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> Votre poste est le moins renseigné de tout l'annuaire : le ministère ne
> publie **ni téléphone, ni fax, ni adresse** — le champ adresse ne contient
> que « DOHA QATAR » — et l'adresse électronique à laquelle je vous écris
> semble être une boîte personnelle plutôt que celle du poste.
>
> **Pourriez-vous me communiquer l'adresse de la chancellerie, un numéro de
> téléphone, et si possible une adresse électronique institutionnelle ?** Pour
> la position, le plus simple est d'ouvrir Google Maps, de poser un repère sur
> le bâtiment, puis « Partager » et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Excellence, Madame,
> Monsieur, l'expression de ma haute considération.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 4. Consulat général du Niger à Dubaï

**À :** nigerdxb@emirates.net.ae
**Objet :** Localisation du consulat pour l'application Diaspo Niger

> Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse publiée pour votre consulat est : *Abau Hain Street, Hamdane Area,
> Villa 130, Deira, P.O. Box 34464*. Le nom de rue ne correspond à aucune voie
> connue des services de cartographie — il comporte probablement une coquille —
> et l'application ne peut donc pas vous placer sur une carte.
>
> **Pourriez-vous me confirmer l'adresse exacte et m'indiquer la position de
> vos bureaux ?** Le plus simple est d'ouvrir Google Maps, de poser un repère
> sur le bâtiment, puis « Partager » et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Madame, Monsieur,
> l'expression de ma considération distinguée.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger
>
> ---
>
> *English — Dear Sir or Madam, I develop* **Diaspo Niger**, *an independent
> application for Nigeriens living abroad, which lists Niger's embassies and
> consulates. The published address for your consulate (Abau Hain Street,
> Hamdane Area, Villa 130, Deira) does not match any street known to mapping
> services, so we cannot show you on a map. Could you confirm the exact address
> and share your location — the simplest way is to drop a pin on your building
> in Google Maps and send me the "Share" link? Your public opening hours would
> also be welcome. Thank you.*

---

## 5. Consulat général du Niger à Khartoum

**À :** dipnigkh@yahoo.com
**Objet :** Localisation du consulat pour l'application Diaspo Niger

> Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> La seule adresse publiée pour votre consulat est une boîte postale
> (*P.O. Box 8245 Khartoum*), qui ne désigne aucun bâtiment. Je relève par
> ailleurs que le téléphone et le fax publiés sont le même numéro
> (*+249 18 347 1187*), ce qui mériterait peut-être une correction.
>
> **Pourriez-vous m'indiquer l'adresse physique et la position de vos
> bureaux ?** Le plus simple est d'ouvrir Google Maps, de poser un repère sur
> le bâtiment, puis « Partager » et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Madame, Monsieur,
> l'expression de ma considération distinguée.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 6. Ambassade du Niger au Koweït

**À :** ambanikwt@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse publiée pour votre ambassade est *B.P. 4451 Hawali 32059* : une
> boîte postale et un nom de quartier, dont on ne peut pas déduire
> l'emplacement de la chancellerie. L'application ne peut donc pas vous placer
> sur une carte.
>
> **Pourriez-vous m'indiquer l'adresse physique et la position de vos
> bureaux ?** Le plus simple est d'ouvrir Google Maps, de poser un repère sur
> le bâtiment, puis « Partager » et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Excellence, Madame,
> Monsieur, l'expression de ma haute considération.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 7. Ambassade du Niger en Égypte — Le Caire

**À :** ambanigercaire@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse publiée pour votre ambassade est *101, Avenue des Pyramides,
> Guizeh*. L'avenue s'étend sur plusieurs kilomètres et les services de
> cartographie n'y localisent pas la chancellerie : l'application ne peut pas
> vous placer sur une carte.
>
> Je relève par ailleurs que les **trois numéros de téléphone publiés n'ont pas
> la même longueur**, ce qui laisse penser qu'au moins un comporte une erreur
> de saisie.
>
> **Pourriez-vous m'indiquer la position de vos bureaux et me confirmer vos
> numéros ?** Pour la position, le plus simple est d'ouvrir Google Maps, de
> poser un repère sur le bâtiment, puis « Partager » et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Excellence, Madame,
> Monsieur, l'expression de ma haute considération.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 8. Ambassade du Niger en Inde — New Delhi

**À :** ambanigerindia@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse publiée pour votre ambassade est *53, Paschimi Marg, Vasant
> Vihar*. Les services de cartographie ne parviennent pas à la résoudre :
> l'application ne peut donc pas vous placer sur une carte.
>
> **Pourriez-vous m'indiquer la position de vos bureaux ?** Le plus simple est
> d'ouvrir Google Maps, de poser un repère sur le bâtiment, puis « Partager »
> et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Excellence, Madame,
> Monsieur, l'expression de ma haute considération.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger
>
> ---
>
> *English — Dear Sir or Madam, I develop* **Diaspo Niger**, *an independent
> application for Nigeriens living abroad, which lists Niger's embassies and
> consulates. The published address (53 Paschimi Marg, Vasant Vihar) cannot be
> resolved by mapping services, so we cannot show your Embassy on a map. Could
> you share your location — the simplest way is to drop a pin on your building
> in Google Maps and send me the "Share" link? Your public opening hours would
> also be welcome. Thank you.*

---

## 9. Ambassade du Niger en Chine — Pékin

**À :** middahmaimouna@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse publiée pour votre ambassade est *1-21 San Li Tun Diplomatic
> Compound, Beijing 100600*. Les services de cartographie ne parviennent pas à
> la résoudre : l'application ne peut pas vous placer sur une carte.
>
> Je me permets par ailleurs de signaler que l'adresse électronique publiée par
> le ministère pour votre poste — celle à laquelle je vous écris — semble être
> une **boîte personnelle plutôt qu'institutionnelle**, ce qui la rendrait
> inutilisable après une mutation.
>
> **Pourriez-vous m'indiquer la position de vos bureaux ?** Le plus simple est
> d'ouvrir Google Maps, de poser un repère sur le bâtiment, puis « Partager »
> et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Excellence, Madame,
> Monsieur, l'expression de ma haute considération.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 10. Ambassade du Niger au Maroc — Rabat

**À :** aambassadeniger@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse publiée pour votre ambassade est *Secteur 7, A4, Avenue Al Haour,
> Hay Riad*. Les services de cartographie ne localisent pas la chancellerie à
> partir de cette indication : l'application ne peut pas vous placer sur une
> carte.
>
> Je relève par ailleurs que le **numéro de fax publié est incomplet**
> (*+212 537 56 68*, deux chiffres manquants).
>
> **Pourriez-vous m'indiquer la position de vos bureaux et me communiquer le
> fax complet ?** Pour la position, le plus simple est d'ouvrir Google Maps, de
> poser un repère sur le bâtiment, puis « Partager » et de me renvoyer le lien.
>
> Si vous en avez le temps, vos **horaires d'ouverture au public**
> compléteraient utilement la fiche.
>
> Je vous remercie par avance et vous prie d'agréer, Excellence, Madame,
> Monsieur, l'expression de ma haute considération.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## 11. Ambassade du Niger à Cuba — La Havane

> ⚠️ **Aucune adresse électronique n'est publiée pour ce poste.** Le ministère
> l'annonce avec « -- » dans les quatre champs. Ce message doit donc être
> adressé au **ministère des Affaires étrangères à Niamey**, et non au poste.
> Le formulaire de contact du site `diplomatie.gouv.ne` est la seule voie
> identifiée à ce jour.

**Objet :** Coordonnées de l'ambassade du Niger à Cuba — fiche vide sur le site du ministère

> Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger à
> partir des informations que publie votre ministère.
>
> Je me permets de signaler que la fiche de l'**ambassade du Niger à Cuba**,
> sur la page « Les ambassades » de diplomatie.gouv.ne, ne comporte **aucune
> information** : téléphone, fax, adresse électronique et adresse postale
> portent tous la mention « -- ». Le poste est donc annoncé, mais aucun
> Nigérien de Cuba ne dispose du moindre moyen de le joindre.
>
> **Pourriez-vous me communiquer ses coordonnées, ou m'indiquer si ce poste
> n'est plus en activité ?** Dans le second cas, il serait utile de préciser
> quel poste couvre Cuba.
>
> Je vous remercie par avance et vous prie d'agréer, Madame, Monsieur,
> l'expression de ma considération distinguée.
>
> [VOTRE NOM]
> [VOTRE FONCTION] — Diaspo Niger

---

## Quand les réponses arrivent

Une position reçue s'écrit en base par une migration, jamais à la main dans la
console — sans quoi le dépôt cesse de refléter ce qui tourne (voir la dérive
constatée sur cette même table le 2026-09-07). Le gabarit :

```sql
UPDATE public.embassies
   SET latitude = <lat>, longitude = <lon>,
       address = '<adresse confirmée>',
       source = 'poste (courriel du <date>)',
       source_checked_at = now()
 WHERE slug = '<slug>';
```

Penser aussi à retirer la réserve devenue caduque dans `data_notes`, et à
**contribuer la position à OpenStreetMap** : le script
`tools/geocode_postes_diplomatiques.mjs` la retrouvera alors tout seul, et
l'information servira au-delà de cette application.
