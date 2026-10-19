import 'package:flutter/material.dart';
import 'change_password_page.dart';

class SetPinPage extends StatelessWidget {
  const SetPinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChangePasswordPage(isPinOnly: true);
  }
}
