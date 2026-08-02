import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/jarvis_theme.dart';
import '../../core/widgets/hud/hud_panel.dart';
import '../../core/widgets/hud/hud_tick_rail.dart';
import '../../core/widgets/jarvis_atmosphere.dart';
import 'auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthController>().login(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!ok && mounted) {
      final err = context.read<AuthController>().error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      body: JarvisAtmosphere(
        intensity: 1.2,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const HudTickRail(days: 24),
                    const SizedBox(height: 28),
                    Text(
                      'JARVIS',
                      style: GoogleFonts.orbitron(
                        color: JarvisTheme.cyanBright,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ACCESS CONSOLE',
                      style: GoogleFonts.rajdhani(
                        color: JarvisTheme.muted,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    HudPanel(
                      title: 'AUTH // CREDENTIALS',
                      expand: false,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'OPERATOR ID / EMAIL'),
                              validator: (v) =>
                                  (v == null || !v.contains('@')) ? 'Valid email required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(labelText: 'ACCESS KEY'),
                              validator: (v) =>
                                  (v == null || v.length < 6) ? 'Min 6 characters' : null,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: auth.loading ? null : _submit,
                              child: auth.loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('INITIALIZE'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                );
                              },
                              child: const Text('REQUEST NEW CLEARANCE'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const HudClock(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
