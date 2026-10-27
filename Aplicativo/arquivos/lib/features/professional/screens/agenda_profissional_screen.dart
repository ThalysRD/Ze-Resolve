import 'package:flutter/material.dart';

import '../../shared/screens/api_screens.dart';

class AgendaProfissionalScreen extends StatelessWidget {
  const AgendaProfissionalScreen({super.key});
  @override
  Widget build(BuildContext context) => const LiveRequestsScreen(agenda: true);
}
