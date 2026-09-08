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
> Ces deux cas ont désormais leur propre message : **Copenhague (§12)** et
> **Abuja (§13)**. Ils ne demandent pas une position manquante mais l'arbitrage
> d'une contradiction — la rédaction diffère donc des dix premiers.
>
> **À envoyer aujourd'hui : §2 Djeddah, §5 Khartoum, §12 Copenhague,
> §13 Abuja.**


Onze postes de l'annuaire n'ont pas de coordonnées géographiques, et **aucune
source publique ne les contient** : OpenStreetMap n'a aucun nœud pour dix
d'entre eux, et le géocodage de leur adresse postale rend un hôtel, un arrêt
de bus ou un centroïde de quartier — jamais la chancellerie. Le constat détaillé
est dans `TESTS_APPAREIL_A_FAIRE.md`.

Il ne reste qu'une voie : **demander la position aux postes eux-mêmes**. Ce
fichier contient les onze messages, **en français et en anglais**, prêts à
envoyer.

## Avant d'envoyer — trois réserves

- **La Havane est injoignable.** Le ministère publie `--` dans les quatre
  champs : ni téléphone, ni adresse, ni e-mail. Son message doit passer par
  le ministère à Niamey, pas par le poste.
- **Doha et Pékin** répondent sur une boîte au nom d'une personne
  (`abdoulbonz@`, `middahmaimouna@`), pas du poste. Elles peuvent être
  périmées depuis une mutation.
- Une adresse Yahoo ne prouve pas qu'elle soit relevée. Prévoir que plusieurs
  restent sans réponse, et relancer par téléphone les postes qui en publient un.

## Français et anglais : lequel envoyer

Le français est la langue officielle du Niger et celle de son corps
diplomatique : **c'est la version à envoyer par défaut**, y compris dans les
pays non francophones. L'anglais sert de second corps de message, sous le
français dans le même envoi — utile si la boîte est relevée par un agent
recruté localement, ce qui est fréquent dans les postes du Golfe, en Inde, en
Chine, en Éthiopie et au Soudan.

Envoyer les deux dans un seul message plutôt que deux messages séparés : c'est
une seule sollicitation, et la version qui parle au lecteur est sous ses yeux.

## Ce qu'on demande, et pourquoi c'est court

Chaque message pose **une** question principale : où se trouve le bâtiment. Une
demande courte obtient une réponse ; une demande qui liste dix champs à
confirmer finit sans réponse du tout.

La façon la plus simple pour eux de répondre — et celle que le message
propose — est un **lien Google Maps** : ouvrir Maps, poser un repère sur le
bâtiment, « Partager », coller le lien. Pas besoin de savoir ce qu'est une
latitude.

Les horaires d'ouverture sont demandés en second, en une phrase, parce qu'on
ne les a pour aucun des 32 postes et qu'un second courrier coûterait plus cher
que cette ligne.

## Signature à compléter

Remplacer `[VOTRE NOM]` / `[YOUR NAME]` et `[VOTRE FONCTION]` /
`[YOUR ROLE]` dans chaque message. Ne pas se présenter comme un service
officiel : Diaspo Niger est une application indépendante, et le dire évite un
malentendu qui coûterait la réponse.

---

## 1. Ambassade du Niger en Éthiopie — Addis-Abeba

**À :** ambnigeradiss@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger
**Subject:** Locating your Chancery for the Diaspo Niger application

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
>
> ---
>
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address published by the Ministry of Foreign Affairs for your Embassy is
> *Kirkos Sub-city, Kebele 02/03, House No 0547, P.O. Box 5791*. It identifies a
> district, but no mapping source allows the Chancery itself to be located from
> it — so the application cannot show you on a map.
>
> **Could you let me know where your offices are?** The simplest way is to open
> Google Maps, drop a pin on the building, then tap "Share" and send me the
> link. A precise street address would work just as well.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 2. Consulat général du Niger à Djeddah

**À :** Djeddah_consulatgnralniger@yahoo.fr
**Objet :** Localisation du consulat pour l'application Diaspo Niger
**Subject:** Locating your Consulate for the Diaspo Niger application

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
>
> ---
>
> Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The only address published for your Consulate is a post office box
> (*P.O. Box 1709 Jeddah 21441*). A PO box identifies no building: the
> application cannot show you on a map, and Nigeriens in Jeddah have no way of
> knowing where to present themselves.
>
> **Could you give me the street address and the location of your offices?**
> The simplest way is to open Google Maps, drop a pin on the building, then tap
> "Share" and send me the link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Yours faithfully,
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 3. Ambassade du Niger au Qatar — Doha

**À :** abdoulbonz@yahoo.fr
**Objet :** Coordonnées de l'ambassade pour l'application Diaspo Niger
**Subject:** Contact details for your Embassy — Diaspo Niger application

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
>
> ---
>
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> Your mission is the least documented entry in the whole directory: the
> Ministry publishes **no telephone, no fax and no address** — the address field
> contains only "DOHA QATAR" — and the email address I am writing to appears to
> be a personal mailbox rather than the mission's own.
>
> **Could you send me the Chancery's address, a telephone number, and if
> possible an institutional email address?** For the location, the simplest way
> is to open Google Maps, drop a pin on the building, then tap "Share" and send
> me the link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 4. Consulat général du Niger à Dubaï

**À :** nigerdxb@emirates.net.ae
**Objet :** Localisation du consulat pour l'application Diaspo Niger
**Subject:** Locating your Consulate for the Diaspo Niger application

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
> Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address published for your Consulate is *Abau Hain Street, Hamdane Area,
> Villa 130, Deira, P.O. Box 34464*. The street name matches no thoroughfare
> known to mapping services — it most likely contains a typing error — so the
> application cannot show you on a map.
>
> **Could you confirm the exact address and let me know where your offices
> are?** The simplest way is to open Google Maps, drop a pin on the building,
> then tap "Share" and send me the link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Yours faithfully,
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 5. Consulat général du Niger à Khartoum

**À :** dipnigkh@yahoo.com
**Objet :** Localisation du consulat pour l'application Diaspo Niger
**Subject:** Locating your Consulate for the Diaspo Niger application

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
>
> ---
>
> Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The only address published for your Consulate is a post office box
> (*P.O. Box 8245 Khartoum*), which identifies no building. I also note that
> the published telephone and fax are the same number (*+249 18 347 1187*),
> which may warrant a correction.
>
> **Could you give me the street address and the location of your offices?**
> The simplest way is to open Google Maps, drop a pin on the building, then tap
> "Share" and send me the link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Yours faithfully,
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 6. Ambassade du Niger au Koweït

**À :** ambanikwt@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger
**Subject:** Locating your Chancery for the Diaspo Niger application

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
>
> ---
>
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address published for your Embassy is *P.O. Box 4451 Hawalli 32059*: a
> post office box and a district name, from which the Chancery's location
> cannot be deduced. The application therefore cannot show you on a map.
>
> **Could you give me the street address and the location of your offices?**
> The simplest way is to open Google Maps, drop a pin on the building, then tap
> "Share" and send me the link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 7. Ambassade du Niger en Égypte — Le Caire

**À :** ambanigercaire@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger
**Subject:** Locating your Chancery for the Diaspo Niger application

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
>
> ---
>
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address published for your Embassy is *101 Pyramids Road, Giza*. The road
> runs for several kilometres and mapping services do not locate the Chancery
> along it, so the application cannot show you on a map.
>
> I also note that the **three published telephone numbers are not the same
> length**, which suggests at least one contains a typing error.
>
> **Could you let me know where your offices are, and confirm your telephone
> numbers?** For the location, the simplest way is to open Google Maps, drop a
> pin on the building, then tap "Share" and send me the link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 8. Ambassade du Niger en Inde — New Delhi

**À :** ambanigerindia@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger
**Subject:** Locating your Chancery for the Diaspo Niger application

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
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address published for your Embassy is *53 Paschimi Marg, Vasant Vihar*.
> Mapping services cannot resolve it, so the application cannot show you on a
> map.
>
> **Could you let me know where your offices are?** The simplest way is to open
> Google Maps, drop a pin on the building, then tap "Share" and send me the
> link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 9. Ambassade du Niger en Chine — Pékin

**À :** middahmaimouna@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger
**Subject:** Locating your Chancery for the Diaspo Niger application

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
>
> ---
>
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address published for your Embassy is *1-21 San Li Tun Diplomatic
> Compound, Beijing 100600*. Mapping services cannot resolve it, so the
> application cannot show you on a map.
>
> May I also point out that the email address the Ministry publishes for your
> mission — the one I am writing to — appears to be a **personal mailbox rather
> than an institutional one**, which would make it unusable after a posting
> change.
>
> **Could you let me know where your offices are?** The simplest way is to open
> Google Maps, drop a pin on the building, then tap "Share" and send me the
> link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 10. Ambassade du Niger au Maroc — Rabat

**À :** aambassadeniger@yahoo.fr
**Objet :** Localisation de la chancellerie pour l'application Diaspo Niger
**Subject:** Locating your Chancery for the Diaspo Niger application

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
>
> ---
>
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address published for your Embassy is *Sector 7, A4, Avenue Al Haour, Hay
> Riad*. Mapping services cannot locate the Chancery from it, so the
> application cannot show you on a map.
>
> I also note that the **published fax number is incomplete**
> (*+212 537 56 68*, two digits missing).
>
> **Could you let me know where your offices are, and send me the full fax
> number?** For the location, the simplest way is to open Google Maps, drop a
> pin on the building, then tap "Share" and send me the link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 11. Ambassade du Niger à Cuba — La Havane

> ⚠️ **Aucune adresse électronique n'est publiée pour ce poste.** Le ministère
> l'annonce avec « -- » dans les quatre champs. Ce message doit donc être
> adressé au **ministère des Affaires étrangères à Niamey**, et non au poste.
> Le formulaire de contact du site `diplomatie.gouv.ne` est la seule voie
> identifiée à ce jour.

**Objet :** Coordonnées de l'ambassade du Niger à Cuba — fiche vide sur le site du ministère
**Subject:** Contact details for the Embassy of Niger in Cuba — entry empty on the Ministry's website

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
>
> ---
>
> Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates from the information your
> Ministry publishes.
>
> May I point out that the entry for the **Embassy of Niger in Cuba**, on the
> "Les ambassades" page of diplomatie.gouv.ne, contains **no information at
> all**: telephone, fax, email and postal address all read "--". The mission is
> therefore listed, yet no Nigerien in Cuba has any means of contacting it.
>
> **Could you send me its contact details, or let me know whether the mission
> is no longer operating?** In the latter case, it would help to know which
> mission covers Cuba.
>
> Thank you in advance. Yours faithfully,
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 12. Ambassade du Niger au Danemark — Copenhague

> ℹ️ **Ce message ne demande pas une position manquante : il fait arbitrer une
> contradiction.** Deux sources placent l'ambassade à 5,1 km l'une de l'autre,
> et rien ne permet de les départager de l'extérieur.

**À :** ambassade@niger.dk
**Objet :** Adresse de la chancellerie — deux localisations divergentes
**Subject:** Chancery address — two conflicting locations

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> Je rencontre une contradiction que je ne peux pas trancher de l'extérieur :
>
> - le ministère des Affaires étrangères publie votre adresse comme
>   *Niels Juels Gade 5* ;
> - les données cartographiques ouvertes (OpenStreetMap) situent l'ambassade
>   du Niger dans le quartier d'**Østerbro, sur Rosbækvej**.
>
> Les deux emplacements sont distants de plus de cinq kilomètres. Afficher le
> mauvais enverrait nos compatriotes à l'autre bout de Copenhague.
>
> **Laquelle est la bonne ?** Si vous avez déménagé, l'annuaire du ministère
> mériterait sans doute d'être mis à jour. Le plus simple pour me confirmer
> l'emplacement est d'ouvrir Google Maps, de poser un repère sur le bâtiment,
> puis « Partager » et de me renvoyer le lien.
>
> Je signale par la même occasion que le **code postal publié est incomplet** :
> le site indique « Dk-059 », alors qu'un code danois comporte quatre chiffres.
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
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> I have come across a contradiction I cannot resolve from the outside:
>
> - the Ministry of Foreign Affairs publishes your address as
>   *Niels Juels Gade 5*;
> - open mapping data (OpenStreetMap) places the Embassy of Niger in the
>   **Østerbro district, on Rosbækvej**.
>
> The two locations are more than five kilometres apart. Showing the wrong one
> would send our compatriots to the other side of Copenhagen.
>
> **Which is correct?** If you have moved, the Ministry's directory would
> likely benefit from an update. The simplest way to confirm the location is to
> open Google Maps, drop a pin on the building, then tap "Share" and send me
> the link.
>
> May I also note that the **published postcode is incomplete**: the website
> shows "Dk-059", whereas Danish postcodes have four digits.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

---

## 13. Ambassade du Niger au Nigeria — Abuja

> ℹ️ **Simple confirmation.** L'adresse publiée et les données cartographiques
> concordent ; il s'agit seulement de valider le point avant de le montrer.

**À :** embniger@yahoo.fr
**Objet :** Confirmation de l'emplacement de la chancellerie
**Subject:** Confirming the location of your Chancery

> Excellence, Madame, Monsieur,
>
> Je développe **Diaspo Niger**, une application indépendante destinée aux
> Nigériens de l'étranger. Elle recense les ambassades et consulats du Niger
> afin que nos compatriotes puissent vous joindre et se rendre chez vous.
>
> L'adresse publiée par le ministère pour votre ambassade est *Plot 933,
> Pope John Paul II Street, Maitama District*, et les données cartographiques
> la confirment. Avant d'afficher ce point à nos utilisateurs, je préfère le
> faire valider par vos soins.
>
> **Pourriez-vous me confirmer que la chancellerie se trouve bien à cette
> adresse ?** Si c'est le cas, une simple réponse « c'est exact » suffit. Sinon,
> le plus simple est d'ouvrir Google Maps, de poser un repère sur le bâtiment,
> puis « Partager » et de me renvoyer le lien.
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
> Your Excellency, Dear Sir or Madam,
>
> I develop **Diaspo Niger**, an independent application for Nigeriens living
> abroad. It lists Niger's embassies and consulates so that our compatriots can
> contact you and find their way to your offices.
>
> The address the Ministry publishes for your Embassy is *Plot 933, Pope John
> Paul II Street, Maitama District*, and mapping data agrees with it. Before
> showing this location to our users, I would rather have it confirmed by you.
>
> **Could you confirm that the Chancery is indeed at this address?** If so, a
> simple "that is correct" is enough. If not, the simplest way is to open
> Google Maps, drop a pin on the building, then tap "Share" and send me the
> link.
>
> If you have a moment, your **public opening hours** would usefully complete
> the entry.
>
> Thank you in advance. Please accept, Your Excellency, Dear Sir or Madam, the
> assurance of my highest consideration.
>
> [YOUR NAME]
> [YOUR ROLE] — Diaspo Niger

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
