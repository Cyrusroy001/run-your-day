import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

Future<void> showAvatarMenu(BuildContext context, {
  required String name, required String subtitle,
  required VoidCallback onSwitchProfile, required VoidCallback onOpenSettings,
  required VoidCallback onOpenGlossary, required VoidCallback onLogout,
  VoidCallback? onPlanWeek,
}) {
  final c = context.c;
  return showModalBottomSheet(context: context, backgroundColor: c.panel2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: c.terra, child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.bricolageGrotesque(fontSize: 18, color: c.cream)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: c.dim)),
          ]),
        ]),
        const Divider(height: 24),
        if (onPlanWeek != null)
          _item(c, Icons.calendar_today_outlined, 'Plan my week', () { Navigator.pop(context); onPlanWeek(); }),
        _item(c, Icons.swap_horiz, 'Switch profile', () { Navigator.pop(context); onSwitchProfile(); }),
        _item(c, Icons.settings_outlined, 'Settings & appearance', () { Navigator.pop(context); onOpenSettings(); }),
        _item(c, Icons.help_outline, 'How ketchup works', () { Navigator.pop(context); onOpenGlossary(); }),
        _item(c, Icons.logout, 'Log out', () { Navigator.pop(context); onLogout(); }),
      ]))));
}

Widget _item(AppPalette c, IconData icon, String label, VoidCallback onTap) =>
    ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: c.sky),
        title: Text(label, style: TextStyle(color: c.cream, fontSize: 14)), onTap: onTap);
