import 'package:flutter/material.dart';

/// A calm fade + gentle upward rise, used for pushed routes across the app so
/// navigation feels of-a-piece rather than the default platform slide. Short
/// enough to feel responsive; eased so it settles rather than snaps.
Route<T> fadeThroughRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
