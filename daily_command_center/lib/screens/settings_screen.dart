import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../data/store.dart';
import '../data/ui_prefs.dart';
import '../theme/app_palette.dart';
import 'glossary_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _id = '';
  String _name = '';
  String _archetype = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await AppStore.repo.loadActive();
    if (!mounted) return;
    setState(() {
      _id = doc.id;
      _name = doc.displayName;
      _archetype = doc.plan.meta.lifestyleArchetype;
    });
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String title, String body,
      {String confirm = 'Confirm', bool destructive = false}) async {
    final c = context.c;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.panel,
        title: Text(title, style: TextStyle(color: c.cream)),
        content: Text(body, style: TextStyle(color: c.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: c.dim))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(confirm, style: TextStyle(color: destructive ? c.terra : c.sky))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _resetPlan() async {
    if (!await _confirm('Reset plan?',
        'Replace your plan with the default blueprint. Your logged history stays.')) {
      return;
    }
    await AppStore.repo.resetPlan(_id);
    _snack('Plan reset to the default blueprint.');
  }

  Future<void> _clearHistory() async {
    if (!await _confirm('Clear history?',
        'Erase every check-off, workout log, and adherence record. Your plan stays.',
        confirm: 'Clear', destructive: true)) {
      return;
    }
    await AppStore.repo.clearHistory(_id);
    _snack('History cleared.');
  }

  Future<void> _export() async {
    final blob = await AppStore.repo.exportProfile(_id);
    await Clipboard.setData(ClipboardData(text: blob));
    _snack('Profile copied to clipboard.');
  }

  Future<void> _import() async {
    final c = context.c;
    final ctrl = TextEditingController();
    final blob = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.panel,
        title: Text('Import profile', style: TextStyle(color: c.cream)),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          style: TextStyle(color: c.cream, fontSize: 12),
          decoration: const InputDecoration(hintText: 'Paste an exported profile JSON'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: c.dim))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text),
              child: Text('Import', style: TextStyle(color: c.sky))),
        ],
      ),
    );
    if (blob == null || blob.trim().isEmpty) return;
    try {
      final meta = await AppStore.repo.importProfile(blob);
      _snack('Imported ${meta.displayName}.');
    } catch (_) {
      _snack('Could not import — that does not look like a valid profile.');
    }
  }

  Future<void> _delete() async {
    if (!await _confirm('Delete profile?',
        'Permanently remove "$_name" and all of its data. This cannot be undone.',
        confirm: 'Delete', destructive: true)) {
      return;
    }
    await AppStore.repo.delete(_id); // also clears the active pointer when current
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _logout() async {
    await AppStore.repo.clearActive();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final appState = RemindersApp.of(context);
    final prefs = appState?.prefs ?? const UiPrefs();

    void setMode(ThemeMode m) => appState?.updatePrefs(prefs.copyWith(themeMode: m));
    void setScale(double s) => appState?.updatePrefs(prefs.copyWith(textScale: s));

    return Scaffold(
      appBar: AppBar(backgroundColor: c.bg, elevation: 0, foregroundColor: c.cream,
          title: Text('Settings', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _section(c, 'PROFILE'),
        Text(_name.isEmpty ? '—' : _name,
            style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: c.cream)),
        if (_archetype.isNotEmpty)
          Text(_archetype, style: TextStyle(fontSize: 12, color: c.dim)),
        const SizedBox(height: 8),
        _action(c, Icons.swap_horiz, 'Log out / switch profile', _logout),

        const SizedBox(height: 20),
        _section(c, 'APPEARANCE'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
          ],
          selected: {prefs.themeMode},
          onSelectionChanged: (s) => setMode(s.first),
        ),
        const SizedBox(height: 16),
        _section(c, 'TEXT SIZE'),
        Slider(value: prefs.textScale, min: 0.9, max: 1.4, divisions: 5,
            label: '${prefs.textScale}x', onChanged: setScale),

        const SizedBox(height: 12),
        _section(c, 'DATA'),
        _action(c, Icons.ios_share, 'Export profile (to clipboard)', _export),
        _action(c, Icons.download, 'Import profile (from clipboard text)', _import),
        _action(c, Icons.restart_alt, 'Reset plan to default', _resetPlan),
        _action(c, Icons.cleaning_services_outlined, 'Clear logged history', _clearHistory),
        _action(c, Icons.delete_outline, 'Delete this profile', _delete, danger: true),

        const SizedBox(height: 12),
        const Divider(),
        ListTile(contentPadding: EdgeInsets.zero,
            title: Text('How Reminders works', style: TextStyle(color: c.cream)),
            trailing: Icon(Icons.chevron_right, color: c.dim),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const GlossaryScreen()))),
      ]),
    );
  }

  Widget _section(AppPalette c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.sky, fontWeight: FontWeight.w600)),
      );

  Widget _action(AppPalette c, IconData icon, String label, VoidCallback onTap,
          {bool danger = false}) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: danger ? c.terra : c.sky),
        title: Text(label, style: TextStyle(color: danger ? c.terra : c.cream)),
        onTap: onTap,
      );
}
