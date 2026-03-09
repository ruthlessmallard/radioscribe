import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'main_menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo / Title
              const Text(
                'RADIO',
                style: TextStyle(
                  color: AppColors.catYellow,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const Text(
                'SCRIBE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 2,
                color: AppColors.catYellow,
                width: 200,
              ),
              const SizedBox(height: 8),
              const Text(
                'MINE RADIO MONITOR',
                style: TextStyle(
                  color: AppColors.greyLight,
                  fontSize: 13,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              // Disclaimer box
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.grey, width: 1),
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.surface,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISCLAIMER',
                      style: TextStyle(
                        color: AppColors.catYellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 10),
                    const Text(
                      'RadioScribe is a supplemental monitoring tool only. '
                      'It does not replace trained personnel, established safety '
                      'protocols, or regulatory compliance requirements.\n\n'
                      'Speech recognition accuracy may be affected by noise, '
                      'radio interference, and signal quality. Critical safety '
                      'decisions must never rely solely on this application.\n\n'
                      'The developers accept no liability for missed alerts, '
                      'false positives, system failures, or any outcomes '
                      'resulting from use or misuse of this application in '
                      'any environment.',
                      style: TextStyle(
                        color: AppColors.textFaded,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 14),
                    const Text(
                      '© Shawn Baird. All rights reserved.\n'
                      'Non-commercial use only. Unauthorized commercial\n'
                      'use, distribution, or modification is prohibited.\n'
                      'Do not share without permission.',
                      style: TextStyle(
                        color: AppColors.greyLight,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Accept button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const MainMenuScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.catYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'I UNDERSTAND — CONTINUE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
