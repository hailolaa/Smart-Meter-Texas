import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/settings/app_settings_store.dart';
import 'smt_signup_guide_screen.dart';
import '../bloc/auth_session_bloc.dart';
import '../bloc/auth_session_event.dart';
import '../bloc/auth_session_state.dart';

class WelcomeBackScreen extends StatefulWidget {
  const WelcomeBackScreen({super.key});

  @override
  State<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends State<WelcomeBackScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() {
    final settings = AppSettingsStore.instance;
    _rememberMe = settings.rememberMe;
    if (_rememberMe) {
      _emailController.text = settings.savedUsername ?? '';
      _passwordController.text = settings.savedPassword ?? '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username and password are required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final settings = AppSettingsStore.instance;
    await settings.setRememberMe(_rememberMe);
    if (_rememberMe) {
      await settings.saveLoginCredentials(
        username: username,
        password: password,
        esiid: '',
      );
    } else {
      await settings.clearSavedCredentials();
    }

    if (!mounted) return;

    context.read<AuthSessionBloc>().add(
      LoginRequested(username: username, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthSessionBloc, AuthSessionState>(
      listener: (context, state) {
        if (state is Authenticated) {
          if (_errorMessage != null) setState(() => _errorMessage = null);
        }
        if (state is Unauthenticated) {
          if (state.reason != null) {
            setState(() => _errorMessage = state.reason);
          }
        }
        if (state is AuthLoading) {
          setState(() => _isSubmitting = true);
        }
        if (state is AuthUnknown || state is Unauthenticated) {
          setState(() => _isSubmitting = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Logo
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryBlue,
                              AppColors.primaryGreen,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "ElectricToday",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Welcome back",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Track your electricity in real time",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Form card ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Email Address",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: "username or email",
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              "Password",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                hintText: "Enter password",
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  key: const Key('password-visibility-toggle'),
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Remember Me
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false,
                                      ),
                                      activeColor: AppColors.primaryBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      side: BorderSide(
                                        color: Colors.grey[400]!,
                                        width: 1.5,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Remember me",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Error banner
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 10),
                              _ThemedLoginErrorCard(message: _errorMessage!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sticky bottom: Login button + Register CTA ──
              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Login button
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryGreen,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Log in",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Register CTA
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          "No SMT account?",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SmtSignupGuideScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                          ),
                          child: const Text(
                            'Register here',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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

class _ThemedLoginErrorCard extends StatelessWidget {
  const _ThemedLoginErrorCard({required this.message});

  final String message;

  bool get _looksCredentialError {
    final m = message.toLowerCase();
    return m.contains('incorrect username') ||
        m.contains('password') ||
        m.contains('credential') ||
        m.contains('invalid');
  }

  String get _title =>
      _looksCredentialError ? 'Login details not correct' : 'Unable to sign in';

  String get _hint => _looksCredentialError
      ? 'Check your username and password, then try again.'
      : 'Please try again in a moment. If this continues, check your network.';

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _hint,
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
