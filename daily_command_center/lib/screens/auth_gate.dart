import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Root widget: shows the login picker when logged out, the app when logged in.
/// Listens to [activeProfile]; flipping that notifier (login / logout) re-routes.
class AuthGate extends StatelessWidget {
  /// Test seam: build the logged-in screen (defaults to a real [HomeShell]).
  final Widget Function(String profileId)? homeBuilder;
  const AuthGate({super.key, this.homeBuilder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: activeProfile,
      builder: (context, id, _) {
        if (id == null) return const LoginScreen();
        return homeBuilder?.call(id) ?? const HomeShell();
      },
    );
  }
}
