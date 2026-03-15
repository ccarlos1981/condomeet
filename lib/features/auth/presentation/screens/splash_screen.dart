import 'package:flutter/material.dart';

/// Splash screen: fundo branco com logo centralizada.
/// Navegação automática é feita pelo AuthBloc via app_router.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 140,
          height: 140,
        ),
      ),
    );
  }
}
