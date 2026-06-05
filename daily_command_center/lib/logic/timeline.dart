import '../data/models.dart';
import 'workouts.dart';

const _wake   = Block(time: '8:00',  cls: 'meal',  label: 'Wake · water · sunlight',         desc: 'Light breakfast: banana + milk/eggs.');
const _focus  = Block(time: '8:30',  cls: 'focus', label: 'Deep Focus — AI Building',         desc: 'Sharpest hour. Phone in another room.');
const _snack  = Block(time: '9:45',  cls: 'meal',  label: 'Break + snack',                    desc: 'Coffee, few nuts. Reset.');
const _brunch = Block(time: '11:30', cls: 'meal',  label: 'Brunch — big protein meal',        desc: 'Eggs + dal + curd + soya. Main protein hit.');
const _commute= Block(time: '1:50',  cls: 'work',  label: 'Walk to office (10 min)',           desc: '');
const _work   = Block(time: '2:00',  cls: 'work',  label: 'Work — 2:00 to 8:00',              desc: 'Fixed block.');
const _lunch3 = Block(time: '3:00',  cls: 'meal',  label: 'Lunch at office',                  desc: 'Dal-bhat + soya or paneer.');
const _snack5 = Block(time: '5:00',  cls: 'meal',  label: 'Light snack at office',            desc: 'Roasted chana, peanuts, or curd.');
const _dinner = Block(time: '8:30',  cls: 'meal',  label: 'Dinner',                           desc: 'Roti + paneer/chicken + saag.');
const _chill  = Block(time: '9:15',  cls: 'chill', label: 'Chill — protected downtime',       desc: 'Yours. No forced work.');
const _wind   = Block(time: '10:45', cls: 'chill', label: 'Wind-down',                        desc: 'Screens dim. Makes the 8am wake work.');
const _sleep  = Block(time: '11:15', cls: 'chill', label: 'Sleep target',                     desc: 'Pull bedtime earlier in 15-min steps.');

Block _dsa(String time) => Block(time: time, cls: 'dsa', label: 'DSA Practice (45 min)', desc: '1–2 problems. Keep coding sharp.');

Block _trainBlock(String day, DayPlan plan) {
  final workout = _workoutFor(day, plan);
  final wo = workouts[workout]!;
  return Block(
    time: _trainTime(plan.schedule),
    cls: 'train',
    label: 'Train — ${wo.title}',
    desc: 'Tap to open workout.',
    isTrain: true,
    workout: workout,
  );
}

String _workoutFor(String day, DayPlan plan) {
  if (plan.schedule == DaySchedule.weekend) {
    return day == 'sat' ? 'BENCH' : 'CARDIO';
  }
  return plan.schedule == DaySchedule.wfh ? 'A' : 'B';
}

String _trainTime(DaySchedule schedule) {
  switch (schedule) {
    case DaySchedule.wfh:     return '11:00';
    case DaySchedule.office:  return '10:00';
    case DaySchedule.weekend: return '11:00';
  }
}

List<Block> buildTimeline(String day, DayPlan plan) {
  if (plan.schedule == DaySchedule.wfh) {
    final base = [
      _wake,
      const Block(time: '8:30',  cls: 'focus', label: 'BIG Project Block (2 hrs)', desc: 'No commute — push a real AI build.'),
      const Block(time: '10:30', cls: 'meal',  label: 'Break + snack',             desc: ''),
    ];
    if (plan.isTraining) base.add(_trainBlock(day, plan));
    base.addAll([
      const Block(time: '12:00', cls: 'meal', label: 'Shower + brunch', desc: 'Big protein meal'),
      _dsa('1:00'), _commute, _work, _lunch3, _snack5, _dinner, _chill, _wind, _sleep,
    ]);
    return base;
  }

  if (plan.schedule == DaySchedule.weekend) {
    final base = [
      _wake,
      const Block(time: '9:00', cls: 'focus', label: 'Focus — AI Building', desc: 'Weekend: relaxed long session.'),
      const Block(time: '10:30', cls: 'meal', label: 'Break + snack', desc: ''),
    ];
    if (plan.isTraining) {
      base.add(_trainBlock(day, plan));
      base.add(const Block(time: '12:00', cls: 'meal', label: 'Shower + big protein meal', desc: ''));
    } else {
      base.add(const Block(time: '11:00', cls: 'dsa', label: 'DSA / project block', desc: 'No training today — extra learning.'));
      base.add(const Block(time: '12:00', cls: 'meal', label: 'Big protein meal', desc: ''));
    }
    base.add(_dsa('1:00'));
    base.add(const Block(time: '2:00', cls: 'chill', label: 'Free afternoon', desc: 'Errands, rest, life.'));
    if (day == 'sun') {
      base.add(const Block(time: '5:00', cls: 'focus', label: 'WEEKLY REVIEW (15 min)', desc: 'Log tracker · read rules · plan next week.'));
    }
    base.addAll([_dinner, _chill, _wind, _sleep]);
    return base;
  }

  // office — training or rest
  if (plan.isTraining) {
    return [_wake, _focus, _snack, _trainBlock(day, plan),
      const Block(time: '11:00', cls: 'meal', label: 'Shower + brunch', desc: 'Big protein meal — office lunch at 3.'),
      _dsa('11:30'), _commute, _work, _lunch3, _snack5, _dinner, _chill, _wind, _sleep];
  }
  return [_wake, _focus, _snack,
    const Block(time: '10:00', cls: 'dsa', label: 'Extra Study Block', desc: 'No training → bigger AI push or extra DSA.'),
    _dsa('11:30'), _brunch, _commute, _work, _lunch3, _snack5, _dinner, _chill, _wind, _sleep];
}

// Resolve block time strings to 24h decimals.
// Walks forward through the day — never moves backward — to correctly
// disambiguate AM vs PM (e.g. "8:30" after "11:15" → 20.5, not 8.5).
List<double> buildTimes(List<Block> blocks) {
  double prev = 0;
  return blocks.map((b) {
    final parts = b.time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final candidates = h == 12 ? [12.0 + m / 60] : [h + m / 60, h + 12.0 + m / 60];
    candidates.sort();
    double val = candidates.last;
    for (final c in candidates) {
      if (c >= prev - 0.001) { val = c; break; }
    }
    prev = val;
    return val;
  }).toList();
}

double nowDecimal() {
  final n = DateTime.now();
  return n.hour + n.minute / 60;
}
