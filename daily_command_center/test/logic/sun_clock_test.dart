import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/sun_clock.dart';

void main() {
  test('phases follow the local clock', () {
    expect(SunClock.phaseAt(6), SkyPhase.dawn);
    expect(SunClock.phaseAt(12), SkyPhase.day);
    expect(SunClock.phaseAt(17.5), SkyPhase.golden);
    expect(SunClock.phaseAt(19), SkyPhase.dusk);
    expect(SunClock.phaseAt(23), SkyPhase.night);
    expect(SunClock.phaseAt(2), SkyPhase.night);
  });

  test('blends crossfade over the 30 min before a boundary', () {
    final b = SunClock.blendAt(7.75); // 15 min before day
    expect(b.phase, SkyPhase.dawn);
    expect(b.next, SkyPhase.day);
    expect(b.t, closeTo(0.5, 0.01));
    expect(SunClock.blendAt(12).t, 0); // mid-phase: no blend
  });
}
