import 'package:flutter/material.dart';

import '../../services/offline_readiness/offline_readiness_service.dart';

class OfflineStatusChip extends StatelessWidget {
  const OfflineStatusChip({
    required this.state,
    this.onTap,
    super.key,
  });

  final OfflineReadinessState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      OfflineReadinessState.ready => ('Offline ready', Colors.green),
      OfflineReadinessState.checking => ('Checking', Colors.amber),
      OfflineReadinessState.problem => ('Map data problem', Colors.red),
    };
    return ActionChip(
      label: Text(label),
      avatar: Icon(Icons.circle, size: 12, color: color),
      onPressed: onTap,
      backgroundColor: color.withAlpha(35),
      side: BorderSide(color: color),
    );
  }
}
