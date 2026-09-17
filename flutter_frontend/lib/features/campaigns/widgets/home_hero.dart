import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';


class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.onProfileTap,
  });

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final gradientTop = scheme.primary;
    final gradientBottom = Color.lerp(
      scheme.primary,
      scheme.primaryContainer,
      0.65,
    )!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientTop, gradientBottom],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha:0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            // Taller hero: more top and bottom padding.
            padding: const EdgeInsets.fromLTRB(20, 28, 16, 66),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final authed = state is AuthAuthenticated;
                final user = authed ? state.user : null;

                final firstName = user?.displayName.split(' ').first;

                final greeting = _timeGreeting();
                final headline = authed && firstName != null
                    ? 'Hi, $firstName'
                    : 'Discover campaigns';

                final subtitle = authed
                    ? 'Ready to make a difference today?'
                    : 'Support causes that matter to you';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _timeIcon(),
                                size: 16,
                                color: Colors.white.withValues(alpha:0.85),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                greeting,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha:0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _AvatarButton(
                      username: user?.username,
                      authed: authed,
                      onTap: onProfileTap,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _timeIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_twilight;
    if (hour < 17) return Icons.wb_sunny_outlined;
    return Icons.nights_stay_outlined;
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.username,
    required this.authed,
    required this.onTap,
  });

  final String? username;
  final bool authed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = (username != null && username!.isNotEmpty)
        ? username![0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha:0.22),
            border: Border.all(
              color: Colors.white.withValues(alpha:0.5),
              width: 1.5,
            ),
          ),
          child: authed
              ? Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 26,
                ),
        ),
      ),
    );
  }
}