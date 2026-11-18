import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unicorn_learning_lab/features/mascot/mascot_states.dart';
import 'package:unicorn_learning_lab/features/mascot/unicorn_mascot.dart';

/// Renders the mascot and returns (horizontal centre of drawn pixels, raw bytes).
Future<(double, Uint8List)> _snapshot(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(of: find.byType(UnicornMascot), matching: find.byType(RepaintBoundary)).first,
  );
  late ui.Image image;
  late ByteData bytes;
  await tester.runAsync(() async {
    image = await boundary.toImage();
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  final w = image.width, h = image.height;
  double sum = 0;
  int n = 0;
  for (int y = 0; y < h; y += 2) {
    for (int x = 0; x < w; x += 2) {
      if (bytes.getUint8((y * w + x) * 4 + 3) > 200) {
        sum += x;
        n++;
      }
    }
  }
  return (n == 0 ? -1.0 : sum / n, bytes.buffer.asUint8List());
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('Uni is never frozen: idle pose keeps changing', (tester) async {
    await tester.pumpWidget(_host(const UnicornMascot(width: 220, height: 220, enter: false, roam: false)));
    await tester.pump(const Duration(milliseconds: 500));
    final (_, a) = await _snapshot(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final (_, b) = await _snapshot(tester);
    expect(listEquals(a, b), isFalse, reason: 'tail/head/breathing should animate continuously');
  });

  testWidgets('Uni wanders around its area when idle', (tester) async {
    await tester.pumpWidget(_host(const UnicornMascot(width: 700, height: 200, enter: false)));
    final xs = <double>[];
    for (int i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      xs.add((await _snapshot(tester)).$1);
    }
    final spread = xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
    expect(spread, greaterThan(80), reason: 'Uni should walk across the stage (positions: $xs)');
  });

  testWidgets('Uni stops roaming to react to an answer', (tester) async {
    Widget at(MascotState s) => _host(UnicornMascot(state: s, width: 700, height: 200, enter: false));
    await tester.pumpWidget(at(MascotState.idle));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(at(MascotState.correctAnswer));
    await tester.pump(const Duration(milliseconds: 100));
    final x1 = (await _snapshot(tester)).$1;
    await tester.pump(const Duration(milliseconds: 1500));
    final x2 = (await _snapshot(tester)).$1;
    expect((x1 - x2).abs(), lessThan(25), reason: 'reaction happens on the spot');
  });
}
