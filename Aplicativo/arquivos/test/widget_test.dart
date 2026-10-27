import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:ze_resolve/features/auth/session/auth_session.dart';
import 'package:ze_resolve/main.dart';
import 'package:ze_resolve/features/auth/screens/login/login_screen.dart';
import 'package:ze_resolve/features/auth/screens/register/register_screen.dart';

void main() {
  testWidgets(
    'login screen is the required first screen when user is not logged in',
    (WidgetTester tester) async {
      AppSession.logout();
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('Bem vindo de volta!'), findsOneWidget);
      expect(find.text('Faça login para continuar'), findsOneWidget);
    },
  );

  testWidgets(
    'senhas não usam sugestões ou autocorreção, inclusive quando visíveis',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      var password = tester.widgetList<TextField>(find.byType(TextField)).last;
      expect(password.obscureText, isTrue);
      expect(password.autocorrect, isFalse);
      expect(password.enableSuggestions, isFalse);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      password = tester.widgetList<TextField>(find.byType(TextField)).last;
      expect(password.obscureText, isFalse);
      expect(password.autocorrect, isFalse);
      expect(password.enableSuggestions, isFalse);

      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final passwords = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList()
          .skip(3);
      expect(passwords.length, 2);
      for (final field in passwords) {
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
      }
    },
  );
}
