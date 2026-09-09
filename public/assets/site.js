/* ==========================================================================
   Diaspo Niger — comportements du site
   Aucune dépendance : tout ce que le site fait tient dans ce fichier.
   ========================================================================== */
(function () {
    'use strict';

    var doux = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    /* ── Mesure d'audience ────────────────────────────────────────────────
       Les événements sont empilés dans dnEvents. Aucun traceur tiers n'est
       chargé : brancher un fournisseur revient à vider cette file au moment
       où on l'accepte, pas avant. */
    window.dnEvents = window.dnEvents || [];
    function suivre(nom, infos) {
        window.dnEvents.push({ e: nom, t: Date.now(), d: infos || null });
    }
    window.dnTrack = suivre;

    document.addEventListener('click', function (ev) {
        var cible = ev.target.closest('[data-ev]');
        if (cible) suivre(cible.getAttribute('data-ev'), cible.getAttribute('data-ev-info'));
    });

    /* ── Barre de navigation ─────────────────────────────────────────────── */
    var nav = document.querySelector('.nav');
    if (nav) {
        var burger = nav.querySelector('.burger');
        var poser = function (ouvert) {
            nav.classList.toggle('open', ouvert);
            if (burger) burger.setAttribute('aria-expanded', ouvert ? 'true' : 'false');
        };

        if (burger) {
            burger.addEventListener('click', function () {
                poser(!nav.classList.contains('open'));
            });
            nav.querySelectorAll('.nav-panel a').forEach(function (a) {
                a.addEventListener('click', function () { poser(false); });
            });
            document.addEventListener('keydown', function (e) {
                if (e.key === 'Escape') poser(false);
            });
            window.addEventListener('resize', function () {
                if (window.innerWidth > 900) poser(false);
            });
        }

        var auScroll = function () {
            nav.classList.toggle('scrolled', window.scrollY > 24);
        };
        auScroll();
        window.addEventListener('scroll', auScroll, { passive: true });
    }

    /* ── Révélation au défilement ────────────────────────────────────────── */
    var aReveler = document.querySelectorAll('.reveal');
    if (aReveler.length) {
        if (doux || !('IntersectionObserver' in window)) {
            aReveler.forEach(function (el) { el.classList.add('in'); });
        } else {
            var obs = new IntersectionObserver(function (entrees) {
                entrees.forEach(function (e, i) {
                    if (!e.isIntersecting) return;
                    var el = e.target;
                    setTimeout(function () { el.classList.add('in'); }, i * 70);
                    obs.unobserve(el);
                });
            }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });
            aReveler.forEach(function (el) { obs.observe(el); });
        }
    }

    /* ── Le héros s'anime une fois, quand il est visible ─────────────────── */
    document.querySelectorAll('.stage').forEach(function (scene) {
        if (doux) { scene.classList.add('play'); return; }
        if (!('IntersectionObserver' in window)) { scene.classList.add('play'); return; }
        var o = new IntersectionObserver(function (entrees) {
            entrees.forEach(function (e) {
                if (!e.isIntersecting) return;
                scene.classList.add('play');
                o.unobserve(scene);
            });
        }, { threshold: 0.2 });
        o.observe(scene);
    });

    /* Les traits du globe se dessinent : chacun doit connaître sa longueur. */
    document.querySelectorAll('.globe .link').forEach(function (trait, i) {
        var l = Math.ceil(trait.getTotalLength ? trait.getTotalLength() : 300);
        trait.style.setProperty('--len', l);
        trait.style.animationDelay = (0.35 + i * 0.18) + 's';
    });
    document.querySelectorAll('.globe .node, .globe .node-halo, .globe .city').forEach(function (el, i) {
        el.style.animationDelay = (0.7 + (i % 6) * 0.14) + 's';
    });

    /* ── Vitrine des fonctionnalités ─────────────────────────────────────── */
    var onglets = Array.prototype.slice.call(document.querySelectorAll('.tab'));
    if (onglets.length) {
        var montrer = function (indice) {
            onglets.forEach(function (t, i) {
                var actif = i === indice;
                t.setAttribute('aria-selected', actif ? 'true' : 'false');
                t.setAttribute('tabindex', actif ? '0' : '-1');
                var vue = document.getElementById(t.getAttribute('aria-controls'));
                if (vue) vue.classList.toggle('on', actif);
            });
        };
        onglets.forEach(function (t, i) {
            t.addEventListener('click', function () {
                montrer(i);
                suivre('click_features', t.dataset.evInfo || String(i));
            });
            /* Un jeu d'onglets se parcourt aux flèches, pas seulement au clic. */
            t.addEventListener('keydown', function (e) {
                var pas = e.key === 'ArrowDown' || e.key === 'ArrowRight' ? 1
                    : e.key === 'ArrowUp' || e.key === 'ArrowLeft' ? -1 : 0;
                if (!pas) return;
                e.preventDefault();
                var suivant = (i + pas + onglets.length) % onglets.length;
                montrer(suivant);
                onglets[suivant].focus();
            });
        });
        montrer(0);
    }

    /* ── Profondeur de lecture ───────────────────────────────────────────── */
    var jalons = [50, 90], atteints = {};
    window.addEventListener('scroll', function () {
        var h = document.documentElement;
        var vu = (h.scrollTop + window.innerHeight) / h.scrollHeight * 100;
        jalons.forEach(function (j) {
            if (vu >= j && !atteints[j]) { atteints[j] = 1; suivre('scroll_' + j); }
        });
    }, { passive: true });

    /* ── Page de téléchargement : ce que le visiteur peut réellement faire ─ */
    var tele = document.querySelector('[data-download]');
    if (tele) {
        var ua = navigator.userAgent;
        var quoi = /android/i.test(ua) ? 'android'
            : /iphone|ipad|ipod/i.test(ua) ? 'ios' : 'bureau';
        tele.setAttribute('data-download', quoi);
        tele.querySelectorAll('[data-when]').forEach(function (bloc) {
            bloc.hidden = bloc.getAttribute('data-when') !== quoi;
        });
        suivre('download_view', quoi);
    }
})();
