import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/connectivity_service.dart';

part 'connectivity_provider.g.dart';

@riverpod
Stream<bool> connectivityStatus(Ref ref) {
  return ConnectivityService.instance.onConnectivityChanged;
}

@riverpod
Future<bool> isConnected(Ref ref) {
  return ConnectivityService.instance.isConnected();
}

@riverpod
class ConnectivityNotifier extends _$ConnectivityNotifier {
  @override
  bool build() {
    _listenToConnectivity();
    return true;
  }

  void _listenToConnectivity() {
    ref.listen(connectivityStatusProvider, (previous, next) {
      next.whenData((isConnected) {
        if (state != isConnected) {
          state = isConnected;
        }
      });
    });
  }

  Future<void> checkConnectivity() async {
    state = await ConnectivityService.instance.isConnected();
  }
}
