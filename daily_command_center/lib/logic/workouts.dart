class WorkoutDef {
  final String title;
  final String why;
  final List<ExerciseDef> exercises;
  const WorkoutDef({required this.title, required this.why, required this.exercises});
}

class ExerciseDef {
  final String name;
  final String sets;
  final String cue;
  const ExerciseDef({required this.name, required this.sets, required this.cue});
}

const workouts = <String, WorkoutDef>{
  'A': WorkoutDef(
    title: 'Full Body A',
    why: 'Hits every major muscle once. Squat + push + pull is the backbone — most shape comes from these.',
    exercises: [
      ExerciseDef(name: 'Goblet squat',        sets: '3–4 × 15–20', cue: 'Hug one dumbbell, lower slow 3s'),
      ExerciseDef(name: 'Push-ups',             sets: '3–4 × max',   cue: 'Main chest builder'),
      ExerciseDef(name: 'Bent-over rows',       sets: '3–4 × 15–20', cue: 'Pull to ribs — builds back'),
      ExerciseDef(name: 'Romanian deadlift',    sets: '3–4 × 15–20', cue: 'Feel the hamstrings'),
      ExerciseDef(name: 'Shoulder press',       sets: '3–4 × 12–15', cue: 'Shoulders = the V-shape'),
      ExerciseDef(name: 'Plank',                sets: '3 × max',     cue: 'Core'),
    ],
  ),
  'B': WorkoutDef(
    title: 'Full Body B',
    why: 'Different angles on the same muscles so they keep getting a fresh challenge with light weights.',
    exercises: [
      ExerciseDef(name: 'Bulgarian split squat', sets: '3–4 × 12–15 ea', cue: 'Rear foot on couch'),
      ExerciseDef(name: 'Floor press',           sets: '3–4 × 15–20',    cue: 'Press dumbbells up'),
      ExerciseDef(name: 'Single-arm row',        sets: '3–4 × 15 ea',    cue: 'One knee on couch'),
      ExerciseDef(name: 'Calf raises',           sets: '3–4 × 20–25',    cue: 'Rise on toes'),
      ExerciseDef(name: 'Curls + triceps',       sets: '3–4 × 15–20',    cue: 'Arm work'),
      ExerciseDef(name: 'Leg raises',            sets: '3 × 15',         cue: 'Lower abs'),
    ],
  ),
  'BENCH': WorkoutDef(
    title: 'Bench + Push',
    why: 'The bench machine is your ONE loadable lift — the only place to add real weight weekly.',
    exercises: [
      ExerciseDef(name: 'Bench press (machine)', sets: '3–4 × 10–12', cue: 'Add weight when you hit 12 all sets'),
      ExerciseDef(name: 'Incline push-ups',      sets: '3 × 12–15',   cue: 'Upper chest'),
      ExerciseDef(name: 'Goblet squat',          sets: '3 × 15–20',   cue: 'Legs'),
      ExerciseDef(name: 'Rows',                  sets: '3 × 15–20',   cue: 'Back'),
      ExerciseDef(name: 'Core circuit',          sets: '~10 min',     cue: 'Planks + leg raises'),
    ],
  ),
  'CARDIO': WorkoutDef(
    title: 'Treadmill + Core',
    why: 'Short bursts burn fat without eating into muscle, and spare a beginner\'s knees vs long runs.',
    exercises: [
      ExerciseDef(name: 'Warm-up walk',  sets: '5 min',         cue: 'Easy'),
      ExerciseDef(name: 'Intervals',     sets: '10–15 rounds',  cue: '30s brisk/incline, 60s easy'),
      ExerciseDef(name: 'Cool-down',     sets: '5 min',         cue: 'Easy walk'),
      ExerciseDef(name: 'Core finish',   sets: '~8 min',        cue: 'Planks, leg raises, side planks'),
    ],
  ),
};
