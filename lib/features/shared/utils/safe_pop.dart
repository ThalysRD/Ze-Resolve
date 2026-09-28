import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav_bar.dart';

void safePop(BuildContext context, {NavUserType userType = NavUserType.client}) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    final homeRoute =
        userType == NavUserType.client ? '/client-home' : '/pro-home';
    Navigator.of(context).pushNamedAndRemoveUntil(homeRoute, (_) => false);
  }
}
