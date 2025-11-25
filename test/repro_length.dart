import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Copy of the relevant logic from main.dart
class TSPConstants {
  static const double blockerRadius = 12.0;
}

double _calculateDistance(Offset a, Offset b) {
  return sqrt(pow(a.dx - b.dx, 2) + pow(a.dy - b.dy, 2));
}

double _calculatePathLength(
  List<int>? currentPath,
  List<Offset> cities,
  bool isManualMode,
  bool isPathClosed,
) {
  if (currentPath == null) return 0.0;
  if (currentPath.length < 2) return 0.0;

  double length = 0.0;
  for (int i = 0; i < currentPath.length - 1; i++) {
    length += _calculateDistance(
      cities[currentPath[i]],
      cities[currentPath[i + 1]],
    );
  }

  // Add distance back to start if path should be closed
  if (currentPath.length > 2 && (!isManualMode || isPathClosed)) {
    length += _calculateDistance(
      cities[currentPath.last],
      cities[currentPath.first],
    );
  }
  return length;
}

void main() {
  test('Path length should be symmetric', () {
    List<Offset> cities = [Offset(10, 10), Offset(100, 100), Offset(50, 200)];

    // Path A -> B -> C
    List<int> path1 = [0, 1, 2];
    double len1 = _calculatePathLength(
      path1,
      cities,
      true,
      false,
    ); // Manual, Open

    // Path C -> B -> A
    List<int> path2 = [2, 1, 0];
    double len2 = _calculatePathLength(
      path2,
      cities,
      true,
      false,
    ); // Manual, Open

    print('Len1: $len1');
    print('Len2: $len2');
    expect(len1, equals(len2));

    // Closed Path
    double len1Closed = _calculatePathLength(
      path1,
      cities,
      false,
      true,
    ); // Solver (Closed)
    double len2Closed = _calculatePathLength(
      path2,
      cities,
      false,
      true,
    ); // Solver (Closed)

    print('Len1Closed: $len1Closed');
    print('Len2Closed: $len2Closed');
    expect(len1Closed, equals(len2Closed));
  });

  test('Floating point accumulation order', () {
    List<Offset> cities = [
      Offset(10.123456, 10.654321),
      Offset(100.987654, 100.123456),
      Offset(50.555555, 200.444444),
      Offset(300.111111, 150.222222),
    ];

    List<int> path1 = [0, 1, 2, 3];
    List<int> path2 = [3, 2, 1, 0];

    double len1 = _calculatePathLength(path1, cities, true, false);
    double len2 = _calculatePathLength(path2, cities, true, false);

    print('Precision Test:');
    print('Len1: ${len1.toStringAsFixed(20)}');
    print('Len2: ${len2.toStringAsFixed(20)}');

    // They might not be EXACTLY equal bit-wise, but should be very close
    expect((len1 - len2).abs() < 1e-10, isTrue);
  });
}
