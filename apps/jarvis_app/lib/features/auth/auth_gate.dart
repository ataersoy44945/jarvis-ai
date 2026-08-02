import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/chat_screen.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (auth.authenticated) {
      return const ChatScreen();
    }
    return const LoginScreen();
  }
}
