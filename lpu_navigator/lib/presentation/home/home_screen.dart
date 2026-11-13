import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../application/map_controller.dart';
import '../../core/problems.dart';
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
                child: readiness.state == OfflineReadinessState.ready &&
                        widget.controller.stylePath != null
                    ? MapLibreMap(
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(31.25, 75.70),
                          zoom: 15,
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
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
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
                          onTap: readiness.state ==
                                  OfflineReadinessState.problem
                              ? () => _showProblems(readiness.problems)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            enabled: false,
                            decoration: const InputDecoration(
                              hintText: 'Search destinations (coming soon)',
                              filled: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'GPS not enabled yet',
                          child: IconButton(
                            onPressed: null,
                            icon: const Icon(Icons.my_location),
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
