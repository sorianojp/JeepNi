import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/firebase_auth_service.dart';

const Color _loginBackgroundColor = Color(0xFF0D47A1);
const Color _loginAccentColor = Color(0xFFFFB300);
const Color _loginSurfaceColor = Color(0xFFF8FAFC);
const Color _loginFieldColor = Color(0xFFF1F5F9);
const Color _loginTextColor = Color(0xFF0F172A);

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
  bool _isRegistering = false;
  bool _obscurePassword = true;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

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

  void _toggleMode(bool register) {
    if (_isRegistering == register) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isRegistering = register;
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _loginBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              'JeepNi',
                              style: textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isRegistering
                            ? 'Create your student account and keep route updates close at hand.'
                            : 'Sign in for live routes, driver tracking, and campus ride updates.',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _loginSurfaceColor,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AuthModeToggle(
                              isRegistering: _isRegistering,
                              onChanged: _toggleMode,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _isRegistering
                                  ? 'Create student account'
                                  : 'Welcome back',
                              style: textTheme.headlineSmall?.copyWith(
                                color: _loginTextColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isRegistering
                                  ? 'Students can sign up here. Driver accounts are created by an admin.'
                                  : 'Use your JeepNi credentials to continue.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.blueGrey.shade700,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axisAlignment: -1,
                                    child: child,
                                  ),
                                );
                              },
                              child: _isRegistering
                                  ? Column(
                                      key: const ValueKey('name-field'),
                                      children: [
                                        _AuthTextField(
                                          controller: _nameController,
                                          label: 'Full name',
                                          hint: 'Juan Dela Cruz',
                                          icon: Icons.badge_outlined,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.name,
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('no-name-field'),
                                    ),
                            ),
                            _AuthTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'you@example.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                            ),
                            const SizedBox(height: 16),
                            _AuthTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              enableSuggestions: false,
                              autocorrect: false,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFEF9A9A),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: const Color(0xFFB71C1C),
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _loginBackgroundColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _loginBackgroundColor
                                      .withValues(alpha: 0.65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        _isRegistering
                                            ? 'Create account'
                                            : 'Log in',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _isRegistering
                                  ? 'Driver accounts are managed by admins.'
                                  : 'Students can create accounts here. Drivers should contact an admin.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.blueGrey.shade600,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => _toggleMode(!_isRegistering),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: _isRegistering
                                      ? 'Already have an account? '
                                      : 'Need a student account? ',
                                ),
                                const TextSpan(
                                  text: 'Switch mode',
                                  style: TextStyle(
                                    color: _loginAccentColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  final bool isRegistering;
  final ValueChanged<bool> onChanged;

  const _AuthModeToggle({required this.isRegistering, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Login',
              selected: !isRegistering,
              onTap: () => onChanged(false),
              textTheme: textTheme,
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Sign Up',
              selected: isRegistering,
              onTap: () => onChanged(true),
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextTheme textTheme;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(
              color: selected ? _loginTextColor : Colors.blueGrey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _loginFieldColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _loginBackgroundColor,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
