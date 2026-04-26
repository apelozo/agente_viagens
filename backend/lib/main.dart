import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/realtime_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TravelApp());
}

class TravelApp extends StatefulWidget {
  const TravelApp({super.key});

  @override
  State<TravelApp> createState() => _TravelAppState();
}

class _TravelAppState extends State<TravelApp> {
  final api = ApiService();
  late final AuthService auth = AuthService(api);
  late final RealtimeService realtime = RealtimeService(api);
  bool logged = false;
  bool showRegister = false;

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agente Pessoal da Viagem',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: Builder(
        builder: (_) {
          if (!logged && showRegister) {
            return RegisterScreen(
              authService: auth,
              onBack: () => setState(() => showRegister = false),
            );
          }
          if (!logged) {
            return LoginScreen(
              authService: auth,
              onLogin: () => setState(() => logged = true),
              onGoRegister: () => setState(() => showRegister = true),
            );
          }
          return HomeScreen(
            api: api,
            realtime: realtime,
            authService: auth,
            onLogout: () {
              realtime.disconnect();
              setState(() {
                logged = false;
                auth.logout();
              });
            },
          );
        },
      ),
    );
  }
}
