import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/message_erreur.dart';
import 'admin_provider.dart' show AuditLogEntry, messageRefusRpcAdmin;

/// Filtres du journal d'audit. Les mêmes alimentent la lecture de l'écran et
/// l'export serveur, pour qu'un export contienne ce que l'écran montre.
class AuditFiltre extends Equatable {
  final String acteur;
  final String action;
  final String? typeRessource;
  final String idRessource;
  final String? resultat;
  final DateTime? du;
  final DateTime? au;

  const AuditFiltre({
    this.acteur = '',
    this.action = '',
    this.typeRessource,
    this.idRessource = '',
    this.resultat,
    this.du,
    this.au,
  });

  bool get vide =>
      acteur.trim().isEmpty &&
      action.trim().isEmpty &&
      typeRessource == null &&
      idRessource.trim().isEmpty &&
      resultat == null &&
      du == null &&
      au == null;

  /// Borne haute exclusive : le jour choisi est inclus en entier.
  DateTime? get auExclu =>
      au == null ? null : DateTime(au!.year, au!.month, au!.day + 1);

  @override
  List<Object?> get props =>
      [acteur, action, typeRessource, idRessource, resultat, du, au];
}

class AuditJournalState extends Equatable {
  final List<AuditLogEntry> lignes;
  final AuditFiltre filtre;
  final bool chargement;
  final bool chargementSuite;
  final bool encoreDesLignes;
  final bool export;
  final String? erreur;

  const AuditJournalState({
    this.lignes = const [],
    this.filtre = const AuditFiltre(),
    this.chargement = false,
    this.chargementSuite = false,
    this.encoreDesLignes = false,
    this.export = false,
    this.erreur,
  });

  AuditJournalState copyWith({
    List<AuditLogEntry>? lignes,
    AuditFiltre? filtre,
    bool? chargement,
    bool? chargementSuite,
    bool? encoreDesLignes,
    bool? export,
    String? erreur,
    bool effacerErreur = false,
  }) =>
      AuditJournalState(
        lignes: lignes ?? this.lignes,
        filtre: filtre ?? this.filtre,
        chargement: chargement ?? this.chargement,
        chargementSuite: chargementSuite ?? this.chargementSuite,
        encoreDesLignes: encoreDesLignes ?? this.encoreDesLignes,
        export: export ?? this.export,
        erreur: effacerErreur ? null : (erreur ?? this.erreur),
      );

  @override
  List<Object?> get props => [
        lignes,
        filtre,
        chargement,
        chargementSuite,
        encoreDesLignes,
        export,
        erreur,
      ];
}

final auditJournalProvider =
    NotifierProvider<AuditJournalNotifier, AuditJournalState>(
        AuditJournalNotifier.new);

/// Lecture filtrée par le serveur, paginée par la date (50 lignes), et export.
///
/// Avant : l'écran lisait les 100 dernières lignes puis filtrait en mémoire —
/// chercher une action d'il y a un mois répondait « aucun résultat » alors que
/// la ligne existait. Un filtre porte désormais sur toute la table.
class AuditJournalNotifier extends Notifier<AuditJournalState> {
  static const taillePage = 50;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  AuditJournalState build() => const AuditJournalState();

  /// Échappe `\`, `%` et `_` : le texte saisi est une sous-chaîne littérale.
  static String echapperLike(String v) => v
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// Valeur d'un filtre `or(...)` de PostgREST, entre guillemets : une virgule
  /// ou une parenthèse saisie n'en change pas la grammaire.
  static String citer(String v) =>
      '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _filtrer(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> q,
    AuditFiltre f,
  ) {
    final acteur = f.acteur.trim();
    if (acteur.isNotEmpty) {
      q = q.or('admin_name.ilike.${citer('%${echapperLike(acteur)}%')},'
          'admin_id.eq.${citer(acteur)}');
    }
    final action = f.action.trim();
    if (action.isNotEmpty) {
      q = q.ilike('action', '%${echapperLike(action)}%');
    }
    if (f.typeRessource != null) q = q.eq('target_type', f.typeRessource!);
    final id = f.idRessource.trim();
    if (id.isNotEmpty) q = q.eq('target_id', id);
    if (f.resultat != null) q = q.eq('result', f.resultat!);
    if (f.du != null) {
      q = q.gte('created_at', DateTime(f.du!.year, f.du!.month, f.du!.day).toUtc().toIso8601String());
    }
    if (f.auExclu != null) {
      q = q.lt('created_at', f.auExclu!.toUtc().toIso8601String());
    }
    return q;
  }

  AuditLogEntry _ligne(Map<String, dynamic> r) => AuditLogEntry(
        id: r['id'] as String,
        adminId: r['admin_id'] as String? ?? '',
        adminName: r['admin_name'] as String?,
        action: r['action'] as String? ?? '',
        targetType: r['target_type'] as String? ?? '',
        targetId: r['target_id'] as String?,
        details: (r['details'] as Map?)?.cast<String, dynamic>(),
        timestamp: DateTime.tryParse('${r['created_at']}')?.toLocal(),
        result: r['result'] as String? ?? 'success',
        reasonCode: r['reason_code'] as String?,
        correlationId: r['correlation_id'] as String?,
      );

  Future<void> appliquer(AuditFiltre filtre) async {
    state = state.copyWith(
        filtre: filtre, chargement: true, effacerErreur: true, lignes: const []);
    try {
      final rows = await _filtrer(_supabase.from('admin_audit_logs').select(), filtre)
          .order('created_at', ascending: false)
          .limit(taillePage);
      state = state.copyWith(
        chargement: false,
        lignes: [for (final r in rows) _ligne(r)],
        encoreDesLignes: rows.length == taillePage,
      );
    } catch (e) {
      // Une erreur de lecture ne ressemble jamais à « aucune ligne ».
      state = state.copyWith(chargement: false, erreur: messageErreurUsager(e));
    }
  }

  Future<void> recharger() => appliquer(state.filtre);

  Future<void> chargerPlus() async {
    if (state.chargementSuite || !state.encoreDesLignes || state.lignes.isEmpty) {
      return;
    }
    final dernier = state.lignes.last.timestamp;
    if (dernier == null) return;
    state = state.copyWith(chargementSuite: true, effacerErreur: true);
    try {
      final rows = await _filtrer(_supabase.from('admin_audit_logs').select(), state.filtre)
          .lt('created_at', dernier.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(taillePage);
      final connus = {for (final l in state.lignes) l.id};
      state = state.copyWith(
        chargementSuite: false,
        lignes: [
          ...state.lignes,
          for (final r in rows)
            if (!connus.contains(r['id'])) _ligne(r),
        ],
        encoreDesLignes: rows.length == taillePage,
      );
    } catch (e) {
      state = state.copyWith(chargementSuite: false, erreur: messageErreurUsager(e));
    }
  }

  /// Exporte les lignes du filtre courant (5000 au plus) en CSV dans le
  /// presse-papiers. Le serveur journalise l'export lui-même. Rend le nombre de
  /// lignes, ou `null` et pose [AuditJournalState.erreur] en cas de refus.
  Future<({int lignes, bool tronque})?> exporter() async {
    final f = state.filtre;
    state = state.copyWith(export: true, effacerErreur: true);
    try {
      final r = await _supabase.rpc('admin_audit_export', params: {
        'p_actor': f.acteur.trim().isEmpty ? null : f.acteur.trim(),
        'p_action': f.action.trim().isEmpty ? null : f.action.trim(),
        'p_resource_type': f.typeRessource,
        'p_resource_id': f.idRessource.trim().isEmpty ? null : f.idRessource.trim(),
        'p_result': f.resultat,
        'p_from': f.du == null
            ? null
            : DateTime(f.du!.year, f.du!.month, f.du!.day).toUtc().toIso8601String(),
        'p_to': f.auExclu?.toUtc().toIso8601String(),
        'p_limit': 5000,
      });
      final m = Map<String, dynamic>.from(r as Map);
      final rows = (m['rows'] as List).cast<Map>();
      await Clipboard.setData(ClipboardData(text: enCsv(rows)));
      state = state.copyWith(export: false);
      return (lignes: rows.length, tronque: m['truncated'] == true);
    } on PostgrestException catch (e) {
      state = state.copyWith(export: false, erreur: messageRefusRpcAdmin(e));
      return null;
    } catch (e) {
      state = state.copyWith(export: false, erreur: messageErreurUsager(e));
      return null;
    }
  }

  static const colonnesCsv = [
    'created_at', 'admin_name', 'admin_id', 'action', 'target_type',
    'target_id', 'result', 'reason_code', 'correlation_id', 'details',
  ];

  /// Une cellule qui commence par `= + - @` serait lue comme une formule par
  /// un tableur : on la préfixe d'une apostrophe.
  static String cellule(Object? v) {
    var s = v == null ? '' : (v is Map || v is List ? jsonEncode(v) : '$v');
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  static String enCsv(List<Map> rows) {
    final b = StringBuffer(colonnesCsv.join(','))..write('\r\n');
    for (final r in rows) {
      b
        ..write(colonnesCsv.map((c) => cellule(r[c])).join(','))
        ..write('\r\n');
    }
    return b.toString();
  }
}
