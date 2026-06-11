import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

Future<void> showAvatarMenu(BuildContext context, {
  required String name, required String subtitle,
  required VoidCallback onSwitchProfile, required VoidCallback onOpenSettings,
  required VoidCallback onOpenGlossary, required VoidCallback onLogout,
  VoidCallback? onPlanWeek, VoidCallback? onCatchup, bool catchupBadge = false,
}) {
  final c = context.c;
  return showModalBottomSheet(context: context, backgroundColor: c.raise2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: c.tomato, child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: c.onAccent))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.bricolageGrotesque(fontSize: 18, color: c.salt)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: c.dim)),
          ]),
        ]),
        const Divider(height: 24),
        if (onPlanWeek != null)
          _item(c, Icons.calendar_today_outlined, 'Plan my week', () { Navigator.pop(context); onPlanWeek(); }),
        if (onCatchup != null)
          _item(c, Icons.bar_chart_rounded, 'Sunday catch-up', () { Navigator.pop(context); onCatchup(); },
              note: catchupBadge ? 'new' : null),
        _item(c, Icons.swap_horiz, 'Switch profile', () { Navigator.pop(context); onSwitchProfile(); }),
        _item(c, Icons.settings_outlined, 'Settings & appearance', () { Navigator.pop(context); onOpenSettings(); }),
        _item(c, Icons.help_outline, 'How ketchup works', () { Navigator.pop(context); onOpenGlossary(); }),
        _item(c, Icons.logout, 'Log out', () { Navigator.pop(context); onLogout(); }),
      ]))));
}

Widget _item(AppPalette c, IconData icon, String label, VoidCallback onTap, {String? note}) =>
    ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: c.tomato),
        title: Text(label, style: TextStyle(color: c.salt, fontSize: 14)),
        trailing: note == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.tomatoDim, borderRadius: BorderRadius.circular(99)),
                child: Text(note, style: TextStyle(color: c.tomato, fontSize: 11, fontWeight: FontWeight.w600))),
        onTap: onTap);
