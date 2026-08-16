import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models.dart';

/// ---------------------------------------------------------------------
/// REPOSITORY
/// ---------------------------------------------------------------------
class DeveloperAuthRepository {
  DeveloperAuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  /// Resolves a username/Zetra ID into its internal auth email, signs
  /// in, then requests an OTP be sent to the user's ZetraMail inbox.
  Future<void> requestLogin({
    required String identifier,
    required String password,
  }) async {
    final email = await _client.rpc(
      'resolve_login_email',
      params: {'identifier_input': identifier.trim()},
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

/// True once there's a real, persisted Supabase session. Restarting the
/// app with a session already present skips straight past login/OTP —
/// OTP is only required at the moment of a fresh sign-in.
final developerLoggedInProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((_) => client.auth.currentSession != null);
});

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
      appBar: AppBar(title: const Text('Developer sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('Sign in with your Zetra ID to publish apps',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _identifier,
                  decoration: const InputDecoration(
                      labelText: 'Username or Zetra ID'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
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
      appBar: AppBar(title: const Text('Check your ZetraMail')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the 6-digit code we sent to your ZetraMail inbox.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (_) => _verify(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify & continue'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _resending ? null : _resend,
                  child: _resending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Didn't get a code? Resend"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
