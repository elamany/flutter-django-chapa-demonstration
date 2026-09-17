import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../main/sign_in_prompt.dart';

class CreateCampaignScreen extends StatelessWidget {
  const CreateCampaignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const SignInPrompt(
            title: 'New Campaign',
            message:
                'To create a campaign, you need to sign in or create an account.',
            icon: Icons.add_circle_outline,
          );
        }

        // Authenticated — real form will go here in a later step.
        return Scaffold(
          appBar: AppBar(title: const Text('Create Campaign')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Create campaign form coming next.'),
            ),
          ),
        );
      },
    );
  }
}