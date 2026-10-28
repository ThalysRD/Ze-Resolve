import 'package:flutter/material.dart';

void safePop(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    Navigator.of(context).pushNamedAndRemoveUntil('/client-home', (_) => false);
  }
}
