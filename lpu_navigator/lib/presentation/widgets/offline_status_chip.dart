import 'package:flutter/material.dart';

import '../../services/offline_readiness/offline_readiness_service.dart';

class OfflineStatusChip extends StatelessWidget {
  const OfflineStatusChip({required this.state, this.onTap, super.key});

  final OfflineReadinessState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      OfflineReadinessState.ready => ('Offline ready', Color(0xff2e7d32)),
      OfflineReadinessState.checking => ('Checking', Color(0xff8a5a00)),
      OfflineReadinessState.problem => ('Map data problem', Color(0xffb71c1c)),
    };
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      avatar: const Icon(Icons.circle, size: 12, color: Colors.white),
      onPressed: onTap ?? () {},
      backgroundColor: color,
      side: BorderSide(color: color),
    );
  }
}
