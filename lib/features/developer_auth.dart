import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_core.dart';
import '../core/models.dart';

/// ---------------------------------------------------------------------
/// REPOSITORY
/// ---------------------------------------------------------------------
class DeveloperAuthRepository {
  DeveloperAuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> requestLogin({
    required String identifier,
    required String password,
  }) async {
    final email = await _client.rpc(
      'resolve_login_email',
      params: {'p_identifier': identifier.trim()},
    ) as String;

    await _client.auth.signInWithPassword(email: email, password: password);
    await _client.rpc('request_developer_otp');
  }

  Future<bool> verifyOtp(String code) async {
    final result = await _client.rpc(
      'verify_developer_otp',
      params: {'p_code': code.trim()},
    );
    return result == true;
  }

  Future<void> resendOtp() async {
    await _client.rpc('request_developer_otp');
  }

  Future<void> signOut() => _client.auth.signOut();
}

final developerAuthRepositoryProvider = Provider<DeveloperAuthRepository>((ref) {
  return DeveloperAuthRepository(ref.watch(supabaseClientProvider));
});

final developerLoggedInProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((_) => client.auth.currentSession != null);
});

/// ---------------------------------------------------------------------
/// SHARED AUTH SCREEN CHROME
/// ---------------------------------------------------------------------
class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZetraColors.errorSoft.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZetraColors.errorSoft.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: ZetraColors.errorSoft, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ZetraColors.errorSoft, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// LOGIN
/// ---------------------------------------------------------------------
class DeveloperLoginScreen extends ConsumerStatefulWidget {
  const DeveloperLoginScreen({super.key});

  @override
  ConsumerState<DeveloperLoginScreen> createState() => _DeveloperLoginScreenState();
}

class _DeveloperLoginScreenState extends ConsumerState<DeveloperLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(developerAuthRepositoryProvider).requestLogin(
            identifier: _identifier.text,
            password: _password.text,
          );
      if (!mounted) return;
      context.push('/developer-otp');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: GlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: GlowIcon(icon: Icons.rocket_launch_rounded)),
                  const SizedBox(height: 24),
                  Text('Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in with your Zetra ID to publish apps',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ZetraColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _identifier,
                    decoration: const InputDecoration(
                      labelText: 'Username or Zetra ID',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _AuthErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shield_outlined, size: 14, color: ZetraColors.textMuted),
                      SizedBox(width: 6),
                      Text('Secured by your Zetra ID',
                          style: TextStyle(fontSize: 12, color: ZetraColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  GradientButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// OTP
/// ---------------------------------------------------------------------
class DeveloperOtpScreen extends ConsumerStatefulWidget {
  const DeveloperOtpScreen({super.key});

  @override
  ConsumerState<DeveloperOtpScreen> createState() => _DeveloperOtpScreenState();
}

class _DeveloperOtpScreenState extends ConsumerState<DeveloperOtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(developerAuthRepositoryProvider)
          .verifyOtp(_code.text);
      if (!mounted) return;
      if (ok) {
        context.go('/developer');
      } else {
        setState(() => _error = 'Incorrect code. Please try again.');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(developerAuthRepositoryProvider).resendOtp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code was sent to your ZetraMail')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: GlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: GlowIcon(icon: Icons.mark_email_read_outlined)),
                const SizedBox(height: 24),
                Text('Check your ZetraMail',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text(
                  'We sent a 6-digit code to your ZetraMail inbox. '
                  'Enter it below to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ZetraColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _AuthErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Verify & continue',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: _loading,
                  onPressed: _loading ? null : _verify,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _resending ? null : _resend,
                    child: _resending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: ZetraColors.accentEnd),
                          )
                        : const Text("Didn't get a code? Resend"),
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
