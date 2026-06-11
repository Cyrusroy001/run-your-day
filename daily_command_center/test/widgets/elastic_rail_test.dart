import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/theme/app_palette.dart';
import 'package:daily_command_center/widgets/elastic_rail.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppPalette.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('renders header and all stop labels', (t) async {
    await t.pumpWidget(_host(const ElasticRail(header: 'Rest of today', stops: [
      RailStop(time: '11:03', label: 'Big project', sub: '2 h deep work', durationMinutes: 120),
      RailStop(time: '~1:19', label: 'DSA practice', sub: '−20 min · 25 min', variant: RailVariant.squeeze, durationMinutes: 25),
    ])));
    expect(find.text('REST OF TODAY'), findsOneWidget);
    expect(find.text('Big project'), findsOneWidget);
    expect(find.text('DSA practice'), findsOneWidget);
  });

  testWidgets('squeeze stop shows its mono delta and ish time', (t) async {
    await t.pumpWidget(_host(const ElasticRail(stops: [
      RailStop(time: '~1:19', label: 'DSA practice', sub: '−20 min · 25 min', variant: RailVariant.squeeze, durationMinutes: 25),
    ])));
    expect(find.text('−20 min · 25 min'), findsOneWidget);
    expect(find.text('~1:19'), findsOneWidget);
  });

  testWidgets('tapping a normal card fires onTap; anchor is non-interactive', (t) async {
    var taps = 0;
    await t.pumpWidget(_host(ElasticRail(stops: [
      RailStop(time: '8:20', label: 'Gym', durationMinutes: 60, onTap: () => taps++),
      const RailStop(time: '2:00', label: 'Work', sub: 'held · 2:00 → 8:00', variant: RailVariant.anchor, locked: true, durationMinutes: 360),
    ])));
    await t.tap(find.text('Gym'));
    expect(taps, 1);
    expect(find.text('◉'), findsOneWidget); // anchor lock glyph
    await t.tap(find.text('Work')); // anchor has no onTap — must not throw or count
    expect(taps, 1);
  });

  testWidgets('done stop tints the card leaf', (t) async {
    await t.pumpWidget(_host(const ElasticRail(stops: [
      RailStop(time: '8:00', label: 'Wake', variant: RailVariant.done, durationMinutes: 30),
    ])));
    final box = t.widget<AnimatedContainer>(find.byKey(const Key('rail-card-0'))).decoration as BoxDecoration;
    expect(box.color, AppPalette.dark.leafDim);
  });

  testWidgets('skip stop is faded and struck through', (t) async {
    await t.pumpWidget(_host(const ElasticRail(stops: [
      RailStop(time: '8:45', label: 'Dinner', sub: 'skipped today', variant: RailVariant.skip, durationMinutes: 45),
    ])));
    final op = t.widget<Opacity>(
        find.ancestor(of: find.text('Dinner'), matching: find.byType(Opacity)).first);
    expect(op.opacity, lessThan(1.0));
    final txt = t.widget<Text>(find.text('Dinner'));
    expect(txt.style!.decoration, TextDecoration.lineThrough);
  });

  test('spineHeight is proportional to duration and clamped 56..120', () {
    expect(ElasticRail.spineHeight(15), 56);
    expect(ElasticRail.spineHeight(120), 120);
    expect(ElasticRail.spineHeight(360), 120); // clamp
    expect(ElasticRail.spineHeight(60), greaterThan(ElasticRail.spineHeight(15)));
    expect(ElasticRail.spineHeight(60), lessThan(ElasticRail.spineHeight(120)));
  });
}
