import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/problems.dart';
import '../services/map/map_asset_provisioner.dart';
import '../services/offline_readiness/offline_readiness_service.dart';

class MapController extends ChangeNotifier {
  MapController({OfflineReadinessService? readinessService})
    : readinessService =
          readinessService ?? OfflineReadinessService(MapAssetProvisioner());

  final OfflineReadinessService readinessService;
  final Duration styleLoadTimeout = AppConstants.styleLoadTimeout;

  OfflineReadiness _readiness = const OfflineReadiness.checking();
  Timer? _styleLoadTimer;
  bool _styleLoaded = false;

  OfflineReadiness get readiness => _readiness;
  String? get stylePath => _readiness.stylePath;

  Future<void> initialize() async {
    _styleLoadTimer?.cancel();
    _styleLoaded = false;
    _readiness = const OfflineReadiness.checking();
    notifyListeners();
    _readiness = await readinessService.check();
    if (_readiness.state == OfflineReadinessState.ready) {
      _styleLoadTimer = Timer(styleLoadTimeout, () {
        if (!_styleLoaded) {
          _readiness = OfflineReadiness(
            state: OfflineReadinessState.problem,
            problems: <MapProblem>[
              MapProblem(
                code: 'style_load_timeout',
                message:
                    'Map style did not finish loading within '
                    '${styleLoadTimeout.inSeconds} seconds.',
              ),
            ],
          );
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void markStyleLoaded() {
    _styleLoaded = true;
    _styleLoadTimer?.cancel();
    // Native glyph-load failures do not trigger the style-loaded callback.
    notifyListeners();
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    super.dispose();
  }
}
