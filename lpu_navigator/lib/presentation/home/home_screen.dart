import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../application/map_controller.dart';
import '../../core/constants.dart';
import '../../core/problems.dart';
import '../../data/models/campus_dataset.dart';
import '../../services/offline_readiness/offline_readiness_service.dart';
import '../widgets/offline_status_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});

  final MapController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final readiness = widget.controller.readiness;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child:
                    readiness.state == OfflineReadinessState.ready &&
                        widget.controller.stylePath != null &&
                        readiness.dataset != null
                    ? MapLibreMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            (readiness.dataset!.bbox.south +
                                    readiness.dataset!.bbox.north) /
                                2,
                            (readiness.dataset!.bbox.west +
                                    readiness.dataset!.bbox.east) /
                                2,
                          ),
                          zoom: AppConstants.defaultMapZoom,
                        ),
                        styleString: widget.controller.stylePath!,
                        onStyleLoadedCallback:
                            widget.controller.markStyleLoaded,
                        compassEnabled: true,
                        attributionEnabled: false,
                      )
                    : const ColoredBox(
                        color: Color(0xfff2efe9),
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).padding.top,
                child: const ColoredBox(
                  color: const Color(0xF5FFFFFF),
                ),
              ),
              SafeArea(
                top: true,
                bottom: false,
                left: false,
                right: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xF5FFFFFF),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Text(
                                'LPU Navigator',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              OfflineStatusChip(
                                state: readiness.state,
                                onTap:
                                    readiness.state ==
                                        OfflineReadinessState.problem
                                    ? () => _showProblems(readiness.problems)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        if (readiness.dataset?.datasetKind ==
                            DatasetKind.placeholder)
                          Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            color: const Color(0xfffff0c2),
                            child: const Text(
                              'PLACEHOLDER DATA - not verified',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                left: false,
                right: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xF5FFFFFF),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            enabled: false,
                            decoration: const InputDecoration(
                              hintText: 'Search destinations (coming soon)',
                              filled: true,
                              fillColor: const Color(0xF5FFFFFF),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'GPS not enabled yet',
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xF5FFFFFF),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: IconButton(
                              onPressed: null,
                              icon: const Icon(Icons.my_location),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProblems(List<MapProblem> problems) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Map data problems',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...problems.map(
              (problem) => ListTile(
                title: Text(problem.message),
                subtitle: Text(problem.code),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
