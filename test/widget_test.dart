import 'package:flutter_test/flutter_test.dart';

import 'package:ze_resolve/features/auth/session/auth_session.dart';
import 'package:ze_resolve/main.dart';

void main() {
  testWidgets('login screen is the required first screen when user is not logged in', (WidgetTester tester) async {
    AppSession.logout();

    await tester.pumpWidget(const MyApp());

    expect(find.text('Bem vindo de volta!'), findsOneWidget);
    expect(find.text('Faça login para continuar'), findsOneWidget);
  });
}
