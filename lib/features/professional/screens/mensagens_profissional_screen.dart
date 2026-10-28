import 'package:flutter/material.dart';

import '../../shared/screens/api_screens.dart';

class MensagensProfissionalScreen extends StatelessWidget {
  const MensagensProfissionalScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const LiveRequestsScreen(messages: true);
}
