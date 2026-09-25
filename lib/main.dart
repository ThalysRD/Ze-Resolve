import 'package:flutter/material.dart';

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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zé Resolve',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF5B800)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      routes: {
        '/client-home': (_) => const HomeClientScreen(),
        '/client-search': (_) => const SearchScreen(),
        '/client-requests': (_) => const MyRequestsScreen(),
        '/client-messages': (_) => const MessagesScreen(),
        '/client-profile': (_) => const ProfileClientScreen(),
        '/pro-home': (_) => const HomeProfessionalScreen(),
        '/pro-agenda': (_) => const AgendaProfissionalScreen(),
        '/pro-requests': (_) => const SolicitacoesRecebidasScreen(),
        '/pro-messages': (_) => const MensagensProfissionalScreen(),
        '/pro-profile': (_) => const MeuPerfilProfissionalScreen(),
        '/pro-reviews': (_) => const AvaliacoesRecebidasScreen(),
      },
    );
  }
}
