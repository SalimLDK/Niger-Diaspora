import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/embassies_provider.dart';
import '../widgets/embassy_list_item.dart';
import '../../../../shared/widgets/error_view.dart';

class EmbassiesScreen extends ConsumerWidget {
  const EmbassiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final embassiesAsync = ref.watch(embassiesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambassades & Consulats'),
        centerTitle: true,
      ),
      body: embassiesAsync.when(
        data: (embassies) {
          if (embassies.isEmpty) {
            return const Center(child: Text('Aucune ambassade trouvée.'));
          }
          return ListView.builder(
            itemCount: embassies.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              return EmbassyListItem(embassy: embassies[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: ErrorView(
                message: 'Erreur: ${error.toString()}',
                onRetry: () => ref.refresh(embassiesListProvider),
              ),
            ),
      ),
    );
  }
}
