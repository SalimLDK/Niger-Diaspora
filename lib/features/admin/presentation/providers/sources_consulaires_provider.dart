import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sources et révisions à faire des services consulaires.
///
/// Lecture seule, sur les tables que les policies `consular.view` ouvrent déjà :
/// aucune écriture ici. Corriger une démarche passe par son brouillon
/// (relecture, approbation, publication) ; vérifier une ambassade, par l'écran
/// des ambassades.
///
/// Ce qui est signalé ne dépend d'aucun délai inventé : une source absente, une
/// vérification jamais faite, une révision datée qui est passée.

SupabaseClient get _supabase => Supabase.instance.client;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

enum ProblemeSource { sansSource, jamaisVerifiee, revisionDepassee, sansRevisionPrevue }

class SourceDemarche {
  const SourceDemarche({
    required this.id,
    required this.titre,
    required this.publiee,
    required this.problemes,
    this.sourceUrl,
    this.editeur,
    this.verifieLe,
    this.revisionLe,
  });
  final String id;
  final String titre;
  final bool publiee;
  final String? sourceUrl;
  final String? editeur;
  final DateTime? verifieLe;
  final DateTime? revisionLe;
  final List<ProblemeSource> problemes;
}

class SourceAmbassade {
  const SourceAmbassade({
    required this.id,
    required this.nom,
    required this.ville,
    required this.problemes,
    this.sourceUrl,
    this.source,
    this.verifieeLe,
  });
  final String id;
  final String nom;
  final String ville;
  final String? sourceUrl;
  final String? source;
  final DateTime? verifieeLe;
  final List<ProblemeSource> problemes;
}

class SourcesConsulaires {
  const SourcesConsulaires(this.demarches, this.ambassades, this.totalDemarches, this.totalAmbassades);

  /// Seulement celles qui ont au moins un problème.
  final List<SourceDemarche> demarches;
  final List<SourceAmbassade> ambassades;
  final int totalDemarches;
  final int totalAmbassades;
}

bool _vide(Object? v) => v is! String || v.trim().isEmpty;

/// Une erreur de lecture reste une erreur : jamais « tout est à jour ».
final sourcesConsulairesProvider = FutureProvider.autoDispose<SourcesConsulaires>((ref) async {
  final maintenant = DateTime.now();
  final d = await _supabase
      .from('demarches_consulaires')
      .select('id, titre, publication_status, source_url, source_publisher, verified_at, next_review_at')
      .order('titre');
  final a = await _supabase
      .from('embassies')
      .select('id, name, city, source, source_url, source_checked_at')
      .order('name');

  final demarches = <SourceDemarche>[];
  for (final r in d) {
    final publiee = r['publication_status'] == 'published';
    final verif = _date(r['verified_at']);
    final revision = _date(r['next_review_at']);
    final p = <ProblemeSource>[
      if (_vide(r['source_url'])) ProblemeSource.sansSource,
      if (verif == null) ProblemeSource.jamaisVerifiee,
      if (revision != null && revision.isBefore(maintenant)) ProblemeSource.revisionDepassee,
      // Une démarche publiée sans date de révision n'est jamais relue d'elle-même.
      if (publiee && revision == null) ProblemeSource.sansRevisionPrevue,
    ];
    if (p.isEmpty) continue;
    demarches.add(SourceDemarche(
      id: '${r['id']}',
      titre: r['titre'] as String? ?? '',
      publiee: publiee,
      sourceUrl: r['source_url'] as String?,
      editeur: r['source_publisher'] as String?,
      verifieLe: verif,
      revisionLe: revision,
      problemes: p,
    ));
  }

  final ambassades = <SourceAmbassade>[];
  for (final r in a) {
    final verif = _date(r['source_checked_at']);
    final p = <ProblemeSource>[
      if (_vide(r['source_url'])) ProblemeSource.sansSource,
      if (verif == null) ProblemeSource.jamaisVerifiee,
    ];
    if (p.isEmpty) continue;
    ambassades.add(SourceAmbassade(
      id: '${r['id']}',
      nom: r['name'] as String? ?? '',
      ville: r['city'] as String? ?? '',
      sourceUrl: r['source_url'] as String?,
      source: r['source'] as String?,
      verifieeLe: verif,
      problemes: p,
    ));
  }
  return SourcesConsulaires(demarches, ambassades, d.length, a.length);
});

String detailSources(Object e) => e is PostgrestException ? e.message : e.toString();
