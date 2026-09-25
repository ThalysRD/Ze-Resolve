import 'package:flutter/material.dart';

import '../../shared/screens/user_profile_screen.dart';

class ProfileClientScreen extends StatelessWidget {
  const ProfileClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserProfileScreen(type: UserProfileType.client);
  }
}
