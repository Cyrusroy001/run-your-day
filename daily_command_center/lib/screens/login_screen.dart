import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/profile_repository.dart';
import '../data/store.dart';
import '../theme/app_palette.dart';
import '../theme/transitions.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Test seam: override profile loading. Defaults to [AppStore.repo.listProfileMetas].
  final Future<List<ProfileMeta>> Function()? profileLoader;
  const LoginScreen({super.key, this.profileLoader});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  List<ProfileMeta> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loader = widget.profileLoader ?? AppStore.repo.listProfileMetas;
    final p = await loader();
    if (mounted) setState(() { _profiles = p; _loading = false; });
  }

  Future<void> _enter(String id) async {
    await AppStore.repo.setActiveProfileId(id);
  }

  Future<void> _continueNew() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final id = ProfileRepository.idFor(name);
    if (_profiles.any((m) => m.id == id)) { await _enter(id); return; }
    if (!mounted) return;
    await Navigator.of(context).push(fadeThroughRoute(OnboardingScreen(displayName: name)));
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 64),
            Text('Reminders 2',
                style: GoogleFonts.fraunces(fontSize: 40, fontWeight: FontWeight.w900, color: c.cream, height: 1.0)),
            const SizedBox(height: 8),
            Text("Who's running the day?",
                style: GoogleFonts.fraunces(fontSize: 16, fontStyle: FontStyle.italic, color: c.muted)),
            const SizedBox(height: 32),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: c.terra))
                  : ListView(children: [
                      if (_profiles.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('No profiles yet — create one below.', style: TextStyle(color: c.dim))),
                      for (final p in _profiles)
                        _ProfileTile(meta: p, onTap: () { _enter(p.id).ignore(); }),
                      const SizedBox(height: 16),
                      _NewProfileField(controller: _nameCtrl, onSubmit: _continueNew),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final ProfileMeta meta;
  final VoidCallback onTap;
  const _ProfileTile({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final initial = meta.displayName.isEmpty ? '?' : meta.displayName[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(radius: 24, backgroundColor: c.terra,
                  child: Text(initial, style: TextStyle(color: c.bg, fontWeight: FontWeight.w800, fontSize: 20))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta.displayName, style: TextStyle(color: c.cream, fontSize: 17, fontWeight: FontWeight.w700)),
                if (meta.archetype.isNotEmpty)
                  Text(meta.archetype, style: TextStyle(color: c.muted, fontSize: 12)),
              ])),
              Icon(Icons.chevron_right, color: c.dim),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NewProfileField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _NewProfileField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const SizedBox(width: 8),
        Icon(Icons.add, color: c.moss),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller,
          style: TextStyle(color: c.cream),
          decoration: InputDecoration(border: InputBorder.none, hintText: 'New profile name',
              hintStyle: TextStyle(color: c.dim)),
          onSubmitted: (_) => onSubmit(),
        )),
        TextButton(onPressed: onSubmit, child: Text('Continue', style: TextStyle(color: c.terra))),
      ]),
    );
  }
}
