import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../models/user_model.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';
import '../../services/nearby_driver_alert_service.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.driver:
        return 'Driver';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Future<void> _logout(BuildContext context) async {
    final authService = context.read<FirebaseAuthService>();
    final trackingService = context.read<FirebaseTrackingService>();
    final user = authService.currentUser;

    if (user != null) {
      await trackingService.stopSharingLocation(user.id);
    }

    authService.logout();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<FirebaseAuthService>();
    final nearbyDriverAlertService = context.watch<NearbyDriverAlertService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        _roleLabel(user.role),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (user.role == UserRole.student) ...[
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blueGrey.shade100),
                ),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: nearbyDriverAlertService.alertsEnabled,
                      onChanged: nearbyDriverAlertService.isUpdatingPreference
                          ? null
                          : (enabled) async {
                              await nearbyDriverAlertService.setAlertsEnabled(
                                enabled,
                              );
                              if (!context.mounted) return;
                              if (nearbyDriverAlertService
                                  .requiresSystemPermission) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Allow system notifications for JeepNi to receive nearby driver alerts.',
                                    ),
                                  ),
                                );
                              }
                            },
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text('Nearby Driver Alerts'),
                      subtitle: Text(
                        nearbyDriverAlertService.settingsDescription,
                      ),
                    ),
                    if (nearbyDriverAlertService.requiresSystemPermission) ...[
                      Divider(height: 1, color: Colors.blueGrey.shade100),
                      ListTile(
                        leading: const Icon(Icons.app_settings_alt_outlined),
                        title: const Text('System Notification Settings'),
                        subtitle: const Text(
                          'Open app settings and allow notifications for JeepNi.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: nearbyDriverAlertService.openAppSettings,
                      ),
                    ],
                    if (nearbyDriverAlertService
                        .notificationsPermissionGranted) ...[
                      Divider(height: 1, color: Colors.blueGrey.shade100),
                      ListTile(
                        leading: const Icon(
                          Icons.notification_important_outlined,
                        ),
                        title: const Text('Send Test Notification'),
                        subtitle: const Text(
                          'Use this device to verify nearby alerts are displayed.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final sent = await nearbyDriverAlertService
                              .sendTestNotification();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                sent
                                    ? 'Test notification sent.'
                                    : 'Enable system notifications for JeepNi first.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blueGrey.shade100),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About JeepNi'),
                    subtitle: const Text(
                      'View app details and feature summary.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.about),
                  ),
                  Divider(height: 1, color: Colors.blueGrey.shade100),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Delete Account'),
                    subtitle: const Text(
                      'Permanently remove your account and live location data.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.accountDelete),
                  ),
                  Divider(height: 1, color: Colors.blueGrey.shade100),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign Out'),
                    subtitle: const Text('Log out from this device.'),
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
