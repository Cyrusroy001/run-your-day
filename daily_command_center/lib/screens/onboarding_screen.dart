import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/profile_repository.dart';
import '../data/store.dart';
import '../logic/onboarding.dart';
import '../theme/app_palette.dart';

class OnboardingScreen extends StatefulWidget {
  final String displayName;
  const OnboardingScreen({super.key, required this.displayName});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  int _trainingDays = 4;
  final Map<String, String> _week = {
    'mon': 'office', 'tue': 'office', 'wed': 'wfh', 'thu': 'office',
    'fri': 'office', 'sat': 'weekend', 'sun': 'weekend_sun',
  };
  static const _steps = 3;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // The new profile clones the default profile's plan as its seed blueprint.
    final seed = (await AppStore.repo.load(ProfileRepository.defaultProfileId)).plan;
    await OnboardingLogic.commit(
      repo: AppStore.repo,
      seed: seed,
      displayName: widget.displayName,
      weekChoices: _week,
      trainingDays: _trainingDays,
    );
    // Pop is deferred to the next frame so Navigator.of(context) is not called
    // from within an async gap that may have changed the tree.
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _next() {
    if (_index < _steps - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 16),
          _ProgressDots(count: _steps, index: _index),
          Expanded(child: PageView(
            controller: _page,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            children: [
              _Welcome(name: widget.displayName),
              _WeekStep(week: _week, onChange: (d, t) => setState(() => _week[d] = t)),
              _TrainingStep(days: _trainingDays, onChange: (n) => setState(() => _trainingDays = n)),
            ],
          )),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: c.terra,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _next,
              child: Text(_index == _steps - 1 ? 'Create' : 'Next',
                  style: TextStyle(color: c.bg, fontWeight: FontWeight.w800, fontSize: 16)),
            )),
          ),
        ]),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int count, index;
  const _ProgressDots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: i == index ? 22 : 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
              color: i == index ? c.terra : c.line,
              borderRadius: BorderRadius.circular(4)),
        ),
    ]);
  }
}

class _Welcome extends StatelessWidget {
  final String name;
  const _Welcome({required this.name});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text('Welcome, $name.',
            style: GoogleFonts.fraunces(
                fontSize: 32, fontWeight: FontWeight.w900, color: c.cream)),
        const SizedBox(height: 12),
        Text(
          "We'll set up a starting routine you can run from day one. "
          "You can fine-tune everything later.",
          style: TextStyle(color: c.muted, fontSize: 15, height: 1.5),
        ),
      ]),
    );
  }
}

class _WeekStep extends StatelessWidget {
  final Map<String, String> week;
  final void Function(String day, String template) onChange;
  const _WeekStep({required this.week, required this.onChange});
  static const _labels = {'office': 'Office', 'wfh': 'WFH'};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Your week',
          style: GoogleFonts.fraunces(
              fontSize: 24, fontWeight: FontWeight.w900, color: c.cream)),
      const SizedBox(height: 4),
      Text('Pick the shape of each weekday.', style: TextStyle(color: c.muted)),
      const SizedBox(height: 16),
      for (final d in days)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                  width: 44,
                  child: Text(d.toUpperCase(),
                      style: TextStyle(
                          color: c.cream, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              if (d == 'sat' || d == 'sun')
                Chip(label: const Text('Weekend'), backgroundColor: c.panel)
              else
                for (final t in const ['office', 'wfh'])
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_labels[t]!),
                        selected: week[d] == t,
                        onSelected: (_) => onChange(d, t),
                      )),
            ])),
    ]);
  }
}

class _TrainingStep extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChange;
  const _TrainingStep({required this.days, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Training days',
              style: GoogleFonts.fraunces(
                  fontSize: 24, fontWeight: FontWeight.w900, color: c.cream)),
          const SizedBox(height: 4),
          Text("How many days a week do you want to train?",
              style: TextStyle(color: c.muted)),
          const SizedBox(height: 24),
          Text('$days days',
              style: GoogleFonts.fraunces(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: c.terra)),
          Slider(
              value: days.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              activeColor: c.terra,
              onChanged: (v) => onChange(v.round())),
        ]));
  }
}
