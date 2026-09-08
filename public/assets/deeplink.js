/* ==========================================================================
   Ouverture dans l'application, pour les liens partagés.

   L'application partage des liens vers ce site : /feed/<id>, /groups/<id>,
   /events/<id>… Firebase les réécrit tous vers la page d'accueil. Sans ce
   panneau, le destinataire tombe sur la page marketing sans aucun chemin vers
   le contenu qu'on lui a envoyé.

   Sur mobile, App Links ouvre l'app sans passer par ici. Ce panneau est le
   recours : app absente, navigateur de bureau, ou WebView qui ne suit pas.
   ========================================================================== */
(function () {
    'use strict';

    var ROUTES = ['feed', 'profile', 'p', 'groups', 'g', 'events', 'businesses',
        'marketplace', 'audio-rooms', 'podcasts', 'calls', 'embassies', 'invite'];

    var chemin = window.location.pathname;
    var bouts = chemin.split('/').filter(Boolean);
    if (!bouts.length || ROUTES.indexOf(bouts[0]) === -1) return;
    /* /invite se suffit à lui-même ; les autres ont besoin d'un identifiant. */
    if (bouts[0] !== 'invite' && bouts.length < 2) return;

    var en = document.documentElement.lang === 'en';
    var t = en ? {
        titre: 'Open in Diaspo Niger',
        texte: 'To see this content, open the Diaspo Niger app on your device.',
        ouvrir: 'Open the app',
        pas: "Don't have the app?",
        play: 'Get it on Google Play',
        rester: 'Stay on the website'
    } : {
        titre: 'Ouvrir dans Diaspo Niger',
        texte: "Pour voir ce contenu, ouvrez l'application Diaspo Niger sur votre appareil.",
        ouvrir: "Ouvrir l'application",
        pas: "Vous n'avez pas l'application ?",
        play: 'Disponible sur Google Play',
        rester: 'Rester sur le site'
    };

    var scheme = 'diasponiger://diasponiger.com' + chemin + window.location.search;
    var PLAY = 'https://play.google.com/store/apps/details?id=com.diasponiger.diasponiger';

    var fond = document.createElement('div');
    fond.className = 'dl';
    fond.setAttribute('role', 'dialog');
    fond.setAttribute('aria-modal', 'true');
    fond.setAttribute('aria-labelledby', 'dl-t');
    fond.innerHTML =
        '<div class="dl-card">' +
        '<img src="/logo-96.png" alt="" width="64" height="64" class="dl-logo">' +
        '<h2 id="dl-t">' + t.titre + '</h2>' +
        '<p>' + t.texte + '</p>' +
        '<a class="btn btn-primary dl-open" href="' + scheme + '">' + t.ouvrir + '</a>' +
        '<p class="dl-small">' + t.pas + '</p>' +
        '<a class="btn btn-ghost" href="' + PLAY + '" target="_blank" rel="noopener" ' +
        'data-ev="download_android" data-ev-info="deeplink">' + t.play + '</a>' +
        '<button class="dl-skip" type="button">' + t.rester + '</button>' +
        '</div>';

    document.body.appendChild(fond);
    document.body.style.overflow = 'hidden';

    var fermer = function () {
        fond.remove();
        document.body.style.overflow = '';
    };
    fond.querySelector('.dl-skip').addEventListener('click', fermer);
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') fermer();
    });
    fond.querySelector('.dl-open').focus();

    /* La bascule automatique n'a de sens que là où le schéma existe : sur un
       navigateur de bureau elle ne produit qu'une boîte d'erreur. */
    if (/Android|iPhone|iPad|iPod/i.test(navigator.userAgent)) {
        setTimeout(function () { window.location.href = scheme; }, 800);
    }
})();
