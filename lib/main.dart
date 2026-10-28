import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/route_observer.dart';

import 'core/api/api_client.dart';
import 'core/api/notification_client.dart';
import 'core/api/push_notifications.dart';
import 'features/auth/session/auth_session.dart';
import 'features/shared/screens/api_screens.dart';

import 'features/auth/screens/login/login_screen.dart';
import 'features/client/screens/home_client_screen.dart';
import 'features/client/screens/messages_screen.dart';
import 'features/client/screens/my_requests_screen.dart';
import 'features/client/screens/profile_client_screen.dart';
import 'features/client/screens/search_screen.dart';
import 'features/professional/screens/agenda_profissional_screen.dart';
import 'features/professional/screens/avaliacoes_recebidas_screen.dart';
import 'features/professional/screens/home_professional_screen.dart';
import 'features/professional/screens/mensagens_profissional_screen.dart';
import 'features/professional/screens/meu_perfil_profissional_screen.dart';
import 'features/professional/screens/solicitacoes_recebidas_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Poppins',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await PushNotifications.instance.initialize();
  PushNotifications.instance.onOpenRequest = (requestId) {
    if (!AppSession.isLoggedIn) return;
    appNavigator.currentState?.push(
      MaterialPageRoute(
        builder: (_) => LiveRequestDetails(requestId: requestId),
      ),
    );
  };
  PushNotifications.instance.onOpenChat = (requestId) {
    if (!AppSession.isLoggedIn) return;
    appNavigator.currentState?.push(
      MaterialPageRoute(
        builder: (_) => LiveChatScreen(requestId: requestId, title: 'Conversa'),
      ),
    );
  };
  NotificationClient.instance.onNewMessage = (message) {
    appMessenger.currentState?.showSnackBar(
      SnackBar(
        content: Text('${message['sender_name']}: ${message['body']}'),
        action: SnackBarAction(
          label: 'Abrir',
          onPressed: () {
            appNavigator.currentState?.push(
              MaterialPageRoute(
                builder: (_) => message['kind'] == 'request_event'
                    ? LiveRequestDetails(
                        requestId: message['request_id'] as int,
                      )
                    : LiveChatScreen(
                        requestId: message['request_id'] as int,
                        title: message['sender_name'] as String,
                      ),
              ),
            );
          },
        ),
      ),
    );
  };
  ApiClient.instance.onUnauthorized = () {
    AppSession.logout();
    unawaited(AppSession.deleteStoredSession().catchError((Object _) {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigator.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  };
  runApp(const MyApp());
}

final appNavigator = GlobalKey<NavigatorState>();
final appMessenger = GlobalKey<ScaffoldMessengerState>();

Widget authenticated(Widget page, String role) =>
    AppSession.isLoggedIn && AppSession.selectedProfile == role
    ? page
    : const LoginScreen();

ThemeData get appTheme => ThemeData(
  fontFamily: 'Poppins',
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF5B800)),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF7F7F7),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFECECEC)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.all(16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFFF5B800),
      foregroundColor: const Color(0xFF1B2430),
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigator,
      navigatorObservers: [appRouteObserver],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
      scaffoldMessengerKey: appMessenger,
      title: 'Zé Resolve',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const SessionGate(),
      routes: {
        '/client-home': (_) =>
            authenticated(const HomeClientScreen(), 'cliente'),
        '/client-search': (_) => authenticated(const SearchScreen(), 'cliente'),
        '/client-requests': (_) =>
            authenticated(const MyRequestsScreen(), 'cliente'),
        '/client-messages': (_) =>
            authenticated(const MessagesScreen(), 'cliente'),
        '/client-profile': (_) =>
            authenticated(const ProfileClientScreen(), 'cliente'),
        '/pro-home': (_) =>
            authenticated(const HomeProfessionalScreen(), 'profissional'),
        '/pro-agenda': (_) =>
            authenticated(const AgendaProfissionalScreen(), 'profissional'),
        '/pro-requests': (_) =>
            authenticated(const SolicitacoesRecebidasScreen(), 'profissional'),
        '/pro-messages': (_) =>
            authenticated(const MensagensProfissionalScreen(), 'profissional'),
        '/pro-profile': (_) =>
            authenticated(const MeuPerfilProfissionalScreen(), 'profissional'),
        '/pro-reviews': (_) =>
            authenticated(const AvaliacoesRecebidasScreen(), 'profissional'),
      },
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<bool> _session;
  @override
  void initState() {
    super.initState();
    _session = AppSession.restore();
  }

  @override
  Widget build(BuildContext context) => RemoteView<bool>(
    future: _session,
    retry: () => setState(() {
      _session = AppSession.restore();
    }),
    builder: (loggedIn) => !loggedIn
        ? const LoginScreen()
        : AppSession.selectedProfile == 'cliente'
        ? const HomeClientScreen()
        : const HomeProfessionalScreen(),
  );
}
