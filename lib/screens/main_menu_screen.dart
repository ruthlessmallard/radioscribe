import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'listen_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Header
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'RADIO',
                      style: TextStyle(
                        color: AppColors.catYellow,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    TextSpan(
                      text: 'SCRIBE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'MINE RADIO MONITOR',
                style: TextStyle(
                  color: AppColors.greyLight,
                  fontSize: 12,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 48),
              // Divider
              Container(height: 1, color: AppColors.grey),
              const SizedBox(height: 48),
              // Main button — LISTEN
              _MenuButton(
                icon: Icons.radio,
                label: 'LISTEN',
                subtitle: 'Start monitoring radio traffic',
                color: AppColors.catYellow,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ListenScreen()),
                ),
              ),
              const SizedBox(height: 20),
              // Settings button
              _MenuButton(
                icon: Icons.settings,
                label: 'SETTINGS',
                subtitle: 'Keywords, alerts, preferences',
                color: AppColors.greyLight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const Spacer(),
              // Version footer
              const Center(
                child: Text(
                  'v1.0.0  ·  © Shawn Baird  ·  Non-commercial use only',
                  style: TextStyle(
                    color: AppColors.greyLight,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4), width: 1),
          borderRadius: BorderRadius.circular(4),
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.greyLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
