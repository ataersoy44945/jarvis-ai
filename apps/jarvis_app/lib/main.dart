import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/theme/jarvis_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_gate.dart';
import 'features/chat/chat_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider(create: (_) => AuthController(api)..bootstrap()),
        ChangeNotifierProxyProvider<AuthController, ChatController>(
          create: (_) => ChatController(api),
          update: (_, auth, chat) {
            final c = chat ?? ChatController(api);
            c.attachAuth(auth);
            return c;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Jarvis',
        debugShowCheckedModeBanner: false,
        theme: JarvisTheme.dark(),
        home: const AuthGate(),
      ),
    );
  }
}
