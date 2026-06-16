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
      backgroundColor: c.char,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 64),
            Text('ketchup.',
                style: GoogleFonts.bricolageGrotesque(fontSize: 40, fontWeight: FontWeight.w800, color: c.salt, height: 1.0, letterSpacing: -1)),
            const SizedBox(height: 8),
            Text("Who's running the day?",
                style: GoogleFonts.bricolageGrotesque(fontSize: 16, fontStyle: FontStyle.italic, color: c.dim)),
            const SizedBox(height: 32),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: c.vine))
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
        color: c.raise,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(radius: 24, backgroundColor: c.vine,
                  child: Text(initial, style: TextStyle(color: c.char, fontWeight: FontWeight.w800, fontSize: 20))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta.displayName, style: TextStyle(color: c.salt, fontSize: 17, fontWeight: FontWeight.w700)),
                if (meta.archetype.isNotEmpty)
                  Text(meta.archetype, style: TextStyle(color: c.dim, fontSize: 12)),
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
        Icon(Icons.add, color: c.vine),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller,
          style: TextStyle(color: c.salt),
          decoration: InputDecoration(border: InputBorder.none, hintText: 'New profile name',
              hintStyle: TextStyle(color: c.dim)),
          onSubmitted: (_) => onSubmit(),
        )),
        TextButton(onPressed: onSubmit, child: Text('Continue', style: TextStyle(color: c.vine))),
      ]),
    );
  }
}
