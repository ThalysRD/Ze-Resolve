import 'package:flutter/material.dart';

import '../../shared/screens/api_screens.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const LiveRequestsScreen(messages: true);
}
