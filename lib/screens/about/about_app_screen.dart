import 'package:flutter/material.dart';

const Color _aboutPrimaryColor = Color(0xFF05056A);
const Color _aboutAccentColor = Color(0xFF1A237E);

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About eJeep'),
        backgroundColor: _aboutPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_aboutPrimaryColor, _aboutAccentColor],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset('assets/logo.png'),
                          ),
                          const SizedBox(width: 14),
                          const Flexible(
                            child: Text(
                              'eJeep',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This project was inspired by the capstone research conducted by the "comCUTErs," an IT student group from the Universidad de Dagupan SITE Department. Furthermore, it is intended to be implemented and used by the university.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _aboutPrimaryColor.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _aboutPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.groups_2_outlined,
                          color: _aboutPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Capstone Inspiration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Inspired by the capstone project of UdD IT students from the group comCUTErs.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const _CapstoneNameLine(name: 'Rica May Simbulan'),
                            const SizedBox(height: 6),
                            const _CapstoneNameLine(name: 'Bryle Navarro'),
                            const SizedBox(height: 6),
                            const _CapstoneNameLine(name: 'Hilarion Ildefonso'),
                            const SizedBox(height: 6),
                            const _CapstoneNameLine(name: 'Trixie Mae Taporco'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _aboutAccentColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/arza-logo.png',
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Copyright © ArzaTechnologies',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Team',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'John Paul Soriano, MIT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jeric Prado, MIT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Christopher James Dela Cruz, MIT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rica May Simbulan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _AboutSectionCard(
                  icon: Icons.info_outline,
                  title: 'What eJeep Does',
                  body:
                      'eJeep helps students view active drivers, lets drivers share their live position, and gives admins live operational visibility.',
                ),
                const SizedBox(height: 12),
                const _AboutSectionCard(
                  icon: Icons.pin_drop_outlined,
                  title: 'Live Tracking',
                  body:
                      'The app uses GPS and Firebase to publish location updates so nearby users can see current positions on the map in real time.',
                ),
                const SizedBox(height: 12),
                const _AboutSectionCard(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Reminder',
                  body:
                      'Location sharing should only be used for actual transport operations.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _AboutSectionCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _aboutPrimaryColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _aboutPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _aboutPrimaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapstoneNameLine extends StatelessWidget {
  final String name;

  const _CapstoneNameLine({required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: TextStyle(
        color: Colors.grey.shade800,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
