import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpu_navigator/presentation/widgets/offline_status_chip.dart';
import 'package:lpu_navigator/services/offline_readiness/offline_readiness_service.dart';

void main() {
  testWidgets('renders all three offline states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Material(child: OfflineStatusChip(state: OfflineReadinessState.ready)),
            Material(child: OfflineStatusChip(state: OfflineReadinessState.checking)),
            Material(child: OfflineStatusChip(state: OfflineReadinessState.problem)),
          ],
        ),
      ),
    );

    expect(find.text('Offline ready'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);
    expect(find.text('Map data problem'), findsOneWidget);
  });
}
