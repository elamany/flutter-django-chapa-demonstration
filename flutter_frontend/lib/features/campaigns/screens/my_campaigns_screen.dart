import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../main/sign_in_prompt.dart';

class MyCampaignsScreen extends StatelessWidget {
  const MyCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const SignInPrompt(
            title: 'My Campaigns',
            message: 'Sign in to create and manage your campaigns.',
            icon: Icons.dashboard_outlined,
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('My Campaigns')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('My campaigns list coming next.'),
            ),
          ),
        );
      },
    );
  }
}