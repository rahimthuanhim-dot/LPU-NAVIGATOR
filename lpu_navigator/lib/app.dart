import 'package:flutter/material.dart';

import 'application/map_controller.dart';
import 'presentation/home/home_screen.dart';

class LpuNavigatorApp extends StatelessWidget {
  const LpuNavigatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LPU Navigator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: HomeScreen(controller: MapController()),
    );
  }
}
