import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  bool _isRegistering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isRegistering && name.isEmpty)) {
      setState(() {
        _isLoading = false;
        _error = 'Email, password, and name are required.';
      });
      return;
    }

    final success = _isRegistering
        ? await authService.registerStudent(
            email: email,
            password: password,
            name: name,
          )
        : await authService.login(email, password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      final role = authService.currentUser!.role;
      switch (role) {
        case UserRole.student:
          context.go('/student');
          break;
        case UserRole.driver:
          context.go('/driver');
          break;
        case UserRole.admin:
          context.go('/admin');
          break;
      }
    } else {
      setState(() {
        _error =
            authService.lastError ??
            (_isRegistering
                ? 'Could not create account. Check the values and try again.'
                : 'Invalid email or password.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistering ? 'JeepNi Sign Up' : 'JeepNi Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_bus, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  _isRegistering
                      ? 'Create your JeepNi account'
                      : 'Welcome to JeepNi Tracking',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isRegistering) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign up is for students only. Driver accounts are created by an admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 16),
                if (_error.isNotEmpty)
                  Text(_error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text(
                          _isRegistering ? 'Create account' : 'Login',
                        ),
                      ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                      _error = '';
                    });
                  },
                  child: Text(
                    _isRegistering
                        ? 'Already have an account? Login'
                        : 'Need an account? Sign up',
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
