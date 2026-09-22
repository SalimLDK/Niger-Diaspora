import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_info.g.dart';

/// Vrai si un transport **réel** est présent.
///
/// Le VPN seul n'en est pas un. Un VPN permanent reste « CONNECTED » en mode
/// avion (SM A515F, 2026-09-22 : réseau par défaut « none », agent VPN seul,
/// `Transports: VPN`) ; en service, il porte le transport qu'il emprunte
/// (`Transports: WIFI|VPN`), donc `wifi` ou `mobile` est là aussi. Compter
/// `vpn` seul faisait sauter les gardes hors ligne : modifier un message
/// annonçait « Une erreur inattendue » au lieu d'une coupure.
bool estConnecte(List<ConnectivityResult> transports) =>
    transports.contains(ConnectivityResult.mobile) ||
    transports.contains(ConnectivityResult.wifi) ||
    transports.contains(ConnectivityResult.ethernet);

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfoImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    try {
      return estConnecte(await _connectivity.checkConnectivity());
    } catch (_) {
      return false;
    }
  }
}

@riverpod
NetworkInfo networkInfo(Ref ref) {
  return NetworkInfoImpl();
}
