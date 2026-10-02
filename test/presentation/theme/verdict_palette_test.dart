import 'dart:math' as math;

import 'package:beachiq/logic/swim_suitability.dart';
import 'package:beachiq/presentation/theme/verdict_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance of a single sRGB channel (0-255).
double _linearize(int channel) {
  final c = channel / 255;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

int _channel(double normalized) => (normalized * 255.0).round() & 0xff;

double _relativeLuminance(Color color) {
  return 0.2126 * _linearize(_channel(color.r)) +
      0.7152 * _linearize(_channel(color.g)) +
      0.0722 * _linearize(_channel(color.b));
}

/// The standard WCAG contrast ratio between two colors, in [1, 21]. >= 4.5
/// is the AA threshold for normal-size text.
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('paletteForVerdict', () {
    test('covers every SwimSuitabilityLevel', () {
      for (final level in SwimSuitabilityLevel.values) {
        expect(() => paletteForVerdict(level), returnsNormally);
      }
    });

    test('is a pure function: same level always returns the same colors', () {
      for (final level in SwimSuitabilityLevel.values) {
        final a = paletteForVerdict(level);
        final b = paletteForVerdict(level);
        expect(a.gradientStart, b.gradientStart);
        expect(a.gradientEnd, b.gradientEnd);
        expect(a.foreground, b.foreground);
        expect(a.icon, b.icon);
      }
    });

    test('good is green, caution is orange, poor is red-orange, unknown is '
        'the existing neutral grey', () {
      expect(
        paletteForVerdict(SwimSuitabilityLevel.good).gradientStart,
        const Color(0xFF1B5E20),
      );
      expect(
        paletteForVerdict(SwimSuitabilityLevel.caution).gradientStart,
        const Color(0xFF92400E),
      );
      expect(
        paletteForVerdict(SwimSuitabilityLevel.poor).gradientStart,
        const Color(0xFF7F1D1D),
      );
      expect(
        paletteForVerdict(SwimSuitabilityLevel.unknown).gradientStart,
        const Color(0xFFD9DBDF),
      );
      expect(
        paletteForVerdict(SwimSuitabilityLevel.unknown).foreground,
        const Color(0xFF2E3057),
      );
    });

    test('every variant keeps >= 4.5:1 contrast between the foreground and '
        'both gradient stops (WCAG AA for normal text)', () {
      for (final level in SwimSuitabilityLevel.values) {
        final palette = paletteForVerdict(level);
        for (final stop in [palette.gradientStart, palette.gradientEnd]) {
          final ratio = _contrastRatio(palette.foreground, stop);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$level: foreground ${palette.foreground} vs stop $stop '
                'contrast was $ratio, below the 4.5:1 WCAG AA minimum',
          );
        }
      }
    });
  });
}
