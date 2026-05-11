import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/app_ui.dart';
import '../../models/user_model.dart';
import '../../services/firebase_auth_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/app_text_field.dart';

const Color _loginBackgroundColor = AppUi.primaryBlue;
const Color _loginAccentColor = AppUi.accentAmber;
const Color _loginSurfaceColor = AppUi.panelSurface;
const Color _loginTextColor = AppUi.textPrimary;

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
          context.go(AppRoutes.student);
          break;
        case UserRole.driver:
          context.go(AppRoutes.driver);
          break;
        case UserRole.admin:
          context.go(AppRoutes.admin);
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
                              'assets/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              'eJeep',
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
                                  : 'Use your eJeep credentials to continue.',
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
                                        AppTextField(
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
                            AppTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'you@example.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
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
                            AppPrimaryButton(
                              label: _isRegistering
                                  ? 'Create account'
                                  : 'Log in',
                              onPressed: _submit,
                              isLoading: _isLoading,
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
