import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../embassies/domain/entities/embassy_entity.dart';
import '../../../embassies/presentation/providers/embassies_provider.dart';

class AdminEmbassyVerificationScreen extends ConsumerWidget {
  const AdminEmbassyVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final embassiesAsync = ref.watch(embassiesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification Ambassades')),
      body: embassiesAsync.when(
        data: (embassies) {
          // Filter to show pending or suspended first
          final pending =
              embassies.where((e) => !e.isVerified && !e.isSuspended).toList();
          final active =
              embassies.where((e) => e.isVerified && !e.isSuspended).toList();
          final suspended = embassies.where((e) => e.isSuspended).toList();

          if (embassies.isEmpty) {
            return const Center(child: Text("Aucune ambassade trouvée"));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                  title: "En attente (${pending.length})",
                  color: Colors.orange,
                ),
                ...pending.map((e) => _EmbassyAdminCard(embassy: e)),
                const SizedBox(height: 20),
              ],
              if (active.isNotEmpty) ...[
                _SectionHeader(
                  title: "Actives (${active.length})",
                  color: Colors.green,
                ),
                ...active.map((e) => _EmbassyAdminCard(embassy: e)),
                const SizedBox(height: 20),
              ],
              if (suspended.isNotEmpty) ...[
                _SectionHeader(
                  title: "Suspendues (${suspended.length})",
                  color: Colors.red,
                ),
                ...suspended.map((e) => _EmbassyAdminCard(embassy: e)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            color: color,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbassyAdminCard extends ConsumerWidget {
  final EmbassyEntity embassy;

  const _EmbassyAdminCard({required this.embassy});

  Future<void> _approve(WidgetRef ref, BuildContext context) async {
    try {
      await ref
          .read(embassiesRepositoryProvider)
          .updateEmbassyStatus(
            embassy.id,
            isVerified: true,
            isSuspended: false,
          );
      // Refresh the list
      ref.invalidate(embassiesListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ambassade ${embassy.name} approuvée')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _reject(WidgetRef ref, BuildContext context) async {
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Rejeter la demande"),
            content: TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: "Raison du rejet"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(embassiesRepositoryProvider)
                        .updateEmbassyStatus(
                          embassy.id,
                          isVerified: false,
                          rejectionReason: reasonController.text,
                        );
                    // Refresh the list
                    ref.invalidate(embassiesListProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ambassade ${embassy.name} rejetée'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "Rejeter",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _suspend(WidgetRef ref, BuildContext context) async {
    try {
      await ref
          .read(embassiesRepositoryProvider)
          .updateEmbassyStatus(embassy.id, isSuspended: true);
      // Refresh the list
      ref.invalidate(embassiesListProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ambassade ${embassy.name} suspendue')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          embassy.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${embassy.city}, ${embassy.country} • Juridiction: ${embassy.jurisdictionCountries.join(", ")}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        leading: Icon(
          embassy.isVerified ? Icons.verified : Icons.hourglass_empty,
          color: embassy.isVerified ? Colors.blue : Colors.orange,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!embassy.isVerified) ...[
                  TextButton.icon(
                    onPressed: () => _reject(ref, context),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      "Rejeter",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approve(ref, context),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      "Approuver",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () => _suspend(ref, context),
                    icon: const Icon(Icons.block, color: Colors.orange),
                    label: const Text(
                      "Suspendre",
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
