import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/routes.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'TRACE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 16),
              const Text(
                'GPS FIELD RECORDER',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Record every route.\nOn your device.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A precise tracker for hikes, rides and field work — '
                'no account, no ads, nothing leaves your phone.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              const _FeatureTile(
                title: 'Full GPS recording',
                subtitle:
                    'Distance, speed, elevation & slope — computed from your phone\'s GPS alone.',
                icon: Icons.route,
              ),
              const SizedBox(height: 20),
              const _FeatureTile(
                title: 'Your maps, offline',
                subtitle:
                    'Satellite & standard map views. Switch anytime during your route.',
                icon: Icons.map,
              ),
              const SizedBox(height: 20),
              const _FeatureTile(
                title: 'Waypoints & follow-back',
                subtitle:
                    'Drop pins on the fly. Auto km markers. Retrace your route when done.',
                icon: Icons.location_pin,
              ),
              const Spacer(),
              const Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    _BadgeText('No ads'),
                    Text('•'),
                    _BadgeText('No tracking'),
                    _BadgeText('•'),
                    _BadgeText('Works offline'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_done', true);
                    if (context.mounted) context.go(Routes.trips);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgeText extends StatelessWidget {
  final String text;

  const _BadgeText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}
