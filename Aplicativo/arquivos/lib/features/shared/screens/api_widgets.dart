import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/user_message.dart';
import '../../auth/session/auth_session.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/notifications_modal.dart';

typedef Json = Map<String, dynamic>;
ApiClient get api => ApiClient.instance;
const statusLabels = {
  'pendente': 'Pendente',
  'aceita': 'Aceita',
  'em_andamento': 'Em andamento',
  'concluida': 'Concluída',
  'cancelada': 'Cancelada',
  'recusada': 'Recusada',
};
String dateLabel(dynamic value) {
  final date = DateTime.parse(value as String).toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} às ${pad(date.hour)}:${pad(date.minute)}';
}

String money(dynamic cents) =>
    'R\$ ${((cents as num) / 100).toStringAsFixed(2).replaceAll('.', ',')}';
bool get isProfessional => AppSession.selectedProfile == 'profissional';
void notify(BuildContext context, Object message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message is String ? message : userErrorMessage(message)),
      ),
    );

class ApiPage extends StatelessWidget {
  const ApiPage({
    super.key,
    required this.title,
    required this.child,
    this.index,
    this.actions,
  });
  final String title;
  final Widget child;
  final int? index;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    appBar: AppBar(
      title: Text(title),
      centerTitle: false,
      actions: [...?actions, const NotificationsButton()],
      backgroundColor: const Color(0xFFF7F7F7),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
        color: Color(0xFF1B2430),
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
    ),
    body: SafeArea(child: child),
    bottomNavigationBar: index == null
        ? null
        : AppBottomNavBar(
            userType: isProfessional
                ? NavUserType.professional
                : NavUserType.client,
            currentIndex: index!,
          ),
  );
}

/// Loading, falha com nova tentativa e dados confirmados compartilhados.
class RemoteView<T> extends StatelessWidget {
  const RemoteView({
    super.key,
    required this.future,
    required this.retry,
    required this.builder,
  });
  final Future<T> future;
  final VoidCallback retry;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    userErrorMessage(snapshot.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: retry,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return builder(snapshot.data as T);
    },
  );
}
