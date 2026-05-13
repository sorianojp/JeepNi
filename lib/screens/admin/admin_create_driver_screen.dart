import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../services/firebase_auth_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/app_text_field.dart';

const Color _adminThemeColor = Color(0xFF1A237E);
const Color _driverThemeColor = Color(0xFF05056A);

class AdminCreateDriverScreen extends StatefulWidget {
  const AdminCreateDriverScreen({super.key});

  @override
  State<AdminCreateDriverScreen> createState() =>
      _AdminCreateDriverScreenState();
}

class _AdminCreateDriverScreenState extends State<AdminCreateDriverScreen> {
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverEmailController = TextEditingController();
  final TextEditingController _driverPasswordController =
      TextEditingController();
  bool _isCreatingDriver = false;
  String? _driverFormMessage;

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverEmailController.dispose();
    _driverPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createDriver(FirebaseAuthService authService) async {
    final name = _driverNameController.text.trim();
    final email = _driverEmailController.text.trim();
    final password = _driverPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _driverFormMessage = 'Driver name, email, and password are required.';
      });
      return;
    }

    setState(() {
      _isCreatingDriver = true;
      _driverFormMessage = null;
    });

    final success = await authService.createDriverAccount(
      email: email,
      password: password,
      name: name,
    );

    if (!mounted) return;

    setState(() {
      _isCreatingDriver = false;
      _driverFormMessage = success
          ? 'Driver account created.'
          : authService.lastError ?? 'Could not create driver account.';
    });

    if (success) {
      _driverNameController.clear();
      _driverEmailController.clear();
      _driverPasswordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Driver'),
        backgroundColor: _adminThemeColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.admin),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _driverThemeColor.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _driverThemeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.directions_bus,
                          color: _driverThemeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Driver Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text('Driver can log in after account creation.'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _driverNameController,
                  label: 'Driver full name',
                  hint: 'Enter full name',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _driverEmailController,
                  keyboardType: TextInputType.emailAddress,
                  label: 'Driver email',
                  hint: 'driver@example.com',
                  icon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _driverPasswordController,
                  obscureText: true,
                  label: 'Temporary password',
                  hint: 'Enter temporary password',
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 12),
                if (_driverFormMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _driverFormMessage!,
                      style: TextStyle(
                        color: _driverFormMessage == 'Driver account created.'
                            ? _driverThemeColor
                            : Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                AppPrimaryButton(
                  label: _isCreatingDriver ? 'Creating...' : 'Create driver',
                  onPressed: () => _createDriver(authService),
                  isLoading: _isCreatingDriver,
                  icon: Icons.person_add,
                  backgroundColor: _driverThemeColor,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
