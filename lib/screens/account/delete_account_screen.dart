import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/app_secondary_button.dart';
import '../../widgets/app_text_field.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_tracking_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;

    final authService = context.read<FirebaseAuthService>();
    final trackingService = context.read<FirebaseTrackingService>();
    final user = authService.currentUser;

    if (user == null) {
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your current password to continue.'),
        ),
      );
      return;
    }

    if (_confirmationController.text.trim().toUpperCase() != 'DELETE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type DELETE to confirm account removal.'),
        ),
      );
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    await trackingService.stopSharingLocation(user.id);
    final success = await authService.deleteCurrentAccount(
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
    });

    if (success) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<FirebaseAuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final error = authService.lastError;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'This action permanently deletes your account.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'eJeep will remove your sign-in account, profile, and live location data for ${user.email}.',
                    style: TextStyle(color: Colors.red.shade900, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Current password',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _passwordController,
              label: 'Current password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const Text(
              'Type DELETE to confirm',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _confirmationController,
              label: 'Confirmation',
              hint: 'DELETE',
              icon: Icons.warning_amber_rounded,
              autocorrect: false,
              enableSuggestions: false,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: _isDeleting ? 'Deleting...' : 'Delete account',
              onPressed: _deleteAccount,
              isLoading: _isDeleting,
              backgroundColor: Colors.red.shade700,
            ),
            const SizedBox(height: 12),
            AppSecondaryButton(
              label: 'Cancel',
              onPressed: _isDeleting ? null : () => context.pop(),
              foregroundColor: Colors.blueGrey.shade800,
              borderColor: Colors.blueGrey.shade100,
            ),
          ],
        ),
      ),
    );
  }
}
