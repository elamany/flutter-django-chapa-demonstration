import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/screens/inactive_screen.dart';
import 'features/main/main_scaffold.dart';

class ChapaApp extends StatelessWidget {
  const ChapaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chapa Donations',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthInitial() || AuthLoading() => const _SplashScreen(),
          AuthAuthenticated() || AuthUnauthenticated() => const MainScaffold(),
          AuthInactive() => const InactiveScreen(),
          // AuthFailure comes from a login attempt on the pushed LoginScreen.
          // Show MainScaffold underneath; the LoginScreen handles the error.
          AuthFailure() => const MainScaffold(),
        };
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}