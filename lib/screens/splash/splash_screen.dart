import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  final String message;

  const SplashScreen({super.key, this.message = 'Preparing your route...'});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF05056A)),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 900),
                        tween: Tween(begin: 0.88, end: 1),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(scale: value, child: child);
                        },
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'eJeep',
                        style: textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Know before you go.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Inspired by the capstone project of UdD IT students from comCUTErs.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Copyright © ArzaTechnologies',
                      textAlign: TextAlign.center,
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
