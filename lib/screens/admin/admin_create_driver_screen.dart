import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/firebase_auth_service.dart';

const Color _adminThemeColor = Color(0xFF1A237E);
const Color _driverThemeColor = Color(0xFF0D47A1);

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
          onPressed: () => context.go('/admin'),
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
                TextField(
                  controller: _driverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Driver full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _driverEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Driver email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _driverPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    border: OutlineInputBorder(),
                  ),
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCreatingDriver
                        ? null
                        : () => _createDriver(authService),
                    style: FilledButton.styleFrom(
                      backgroundColor: _driverThemeColor,
                    ),
                    icon: _isCreatingDriver
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add),
                    label: Text(
                      _isCreatingDriver ? 'Creating...' : 'Create driver',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
