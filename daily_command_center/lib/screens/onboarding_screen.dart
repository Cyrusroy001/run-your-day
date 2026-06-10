import 'package:flutter/material.dart';

/// Stub — will be fully implemented in L9.
class OnboardingScreen extends StatelessWidget {
  final String displayName;
  const OnboardingScreen({super.key, required this.displayName});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('Onboarding for $displayName')));
}
