/// Pure local-clock sun curve (ADR-022): no location API. Light always means
/// time; drift never recolors the sky.
enum SkyPhase { dawn, day, golden, dusk, night }

class SkyBlend {
  final SkyPhase phase, next;
  final double t; // 0 = pure [phase], 1 = pure [next]
  const SkyBlend(this.phase, this.next, this.t);
}

class SunClock {
  /// boundary hour (24h decimal) → the phase that starts there.
  static const _bounds = <(double, SkyPhase)>[
    (5.0, SkyPhase.dawn),
    (8.0, SkyPhase.day),
    (16.5, SkyPhase.golden),
    (18.5, SkyPhase.dusk),
    (20.0, SkyPhase.night),
  ];
  static const _fade = 0.5; // crossfade window before each boundary (hours)

  static SkyPhase phaseAt(double h) {
    var p = SkyPhase.night;
    for (final (start, phase) in _bounds) {
      if (h >= start) p = phase;
    }
    return p;
  }

  static SkyBlend blendAt(double h) {
    final p = phaseAt(h);
    for (final (start, next) in _bounds) {
      final d = start - h;
      if (d > 0 && d <= _fade) return SkyBlend(p, next, 1 - d / _fade);
    }
    return SkyBlend(p, p, 0);
  }
}
