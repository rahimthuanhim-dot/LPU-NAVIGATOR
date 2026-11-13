import '../../core/problems.dart';
import '../../data/repositories/campus_repository.dart';
import '../../data/validation/dataset_validator.dart';
import '../../data/models/campus_dataset.dart';
import '../map/map_asset_provisioner.dart';

enum OfflineReadinessState { checking, ready, problem }

class OfflineReadiness {
  const OfflineReadiness({
    required this.state,
    this.problems = const <MapProblem>[],
    this.stylePath,
    this.dataset,
    this.warnings = const <String>[],
  });

  const OfflineReadiness.checking()
    : state = OfflineReadinessState.checking,
      problems = const <MapProblem>[],
      stylePath = null,
      dataset = null,
      warnings = const <String>[];

  final OfflineReadinessState state;
  final List<MapProblem> problems;
  final String? stylePath;
  final CampusDataset? dataset;
  final List<String> warnings;
}

class OfflineReadinessService {
  OfflineReadinessService(
    this.provisioner, {
    CampusRepository? repository,
    DatasetValidator? validator,
  }) : repository = repository ?? CampusRepository(),
       validator = validator ?? DatasetValidator();

  final MapAssetProvisioner provisioner;
  final CampusRepository repository;
  final DatasetValidator validator;
  OfflineReadiness current = const OfflineReadiness.checking();

  Future<OfflineReadiness> check() async {
    current = const OfflineReadiness.checking();
    late final CampusDataset dataset;
    try {
      dataset = await repository.load();
    } on DatasetException catch (error) {
      current = OfflineReadiness(
        state: OfflineReadinessState.problem,
        problems: <MapProblem>[
          MapProblem(
            code: 'dataset_load',
            message: error.toString(),
            path: error.path,
          ),
        ],
      );
      return current;
    }

    final report = validator.validate(dataset);
    final problems = report.errors
        .map(
          (error) => MapProblem(
            code: 'dataset_validation',
            message: error,
            path: repository.assetPath,
          ),
        )
        .toList();
    if (problems.isNotEmpty) {
      current = OfflineReadiness(
        state: OfflineReadinessState.problem,
        dataset: dataset,
        problems: problems,
        warnings: report.warnings,
      );
      return current;
    }

    final result = await provisioner.provision(dataset: dataset);
    if (!result.isReady) {
      current = OfflineReadiness(
        state: OfflineReadinessState.problem,
        dataset: dataset,
        problems: result.problems,
        warnings: report.warnings,
      );
      return current;
    }
    current = OfflineReadiness(
      state: OfflineReadinessState.ready,
      stylePath: result.stylePath,
      dataset: dataset,
      warnings: report.warnings,
    );
    return current;
  }
}
