import '../../core/problems.dart';
import '../map/map_asset_provisioner.dart';

enum OfflineReadinessState { checking, ready, problem }

class OfflineReadiness {
  const OfflineReadiness({
    required this.state,
    this.problems = const <MapProblem>[],
    this.stylePath,
  });

  const OfflineReadiness.checking()
      : state = OfflineReadinessState.checking,
        problems = const <MapProblem>[],
        stylePath = null;

  final OfflineReadinessState state;
  final List<MapProblem> problems;
  final String? stylePath;
}

class OfflineReadinessService {
  OfflineReadinessService(this.provisioner);

  final MapAssetProvisioner provisioner;
  OfflineReadiness current = const OfflineReadiness.checking();

  Future<OfflineReadiness> check() async {
    current = const OfflineReadiness.checking();
    final result = await provisioner.provision();
    current = result.isReady
        ? OfflineReadiness(
            state: OfflineReadinessState.ready,
            stylePath: result.stylePath,
          )
        : OfflineReadiness(
            state: OfflineReadinessState.problem,
            problems: result.problems,
          );
    return current;
  }
}
