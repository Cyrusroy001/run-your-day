import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../data/ui_prefs.dart';
import '../theme/app_palette.dart';
import 'glossary_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final appState = RemindersApp.of(context);
    final prefs = appState?.prefs ?? const UiPrefs();

    void setMode(ThemeMode m) => appState?.updatePrefs(prefs.copyWith(themeMode: m));
    void setScale(double s) => appState?.updatePrefs(prefs.copyWith(textScale: s));

    return Scaffold(
      appBar: AppBar(backgroundColor: c.bg, elevation: 0, foregroundColor: c.cream,
          title: Text('Settings', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('APPEARANCE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
          ],
          selected: {prefs.themeMode},
          onSelectionChanged: (s) => setMode(s.first),
        ),
        const SizedBox(height: 20),
        Text('TEXT SIZE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
        Slider(value: prefs.textScale, min: 0.9, max: 1.4, divisions: 5, label: '${prefs.textScale}x', onChanged: setScale),
        const Divider(),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('How Reminders works', style: TextStyle(color: c.cream)),
            trailing: Icon(Icons.chevron_right, color: c.dim),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlossaryScreen()))),
      ]),
    );
  }
}
