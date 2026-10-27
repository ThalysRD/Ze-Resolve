import 'package:flutter/material.dart';

import '../../../../core/errors/user_message.dart';

import '../register/register_screen.dart';
import '../../session/auth_session.dart';
import '../../../client/screens/home_client_screen.dart';
import '../../../professional/screens/home_professional_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _busy = false;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await AppSession.login(_email.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AppSession.selectedProfile == 'cliente'
              ? const HomeClientScreen()
              : const HomeProfessionalScreen(),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const _BackButton(),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Alinha os textos à esquerda
                    children: [
                      Text(
                        'Bem vindo de volta!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      Text(
                        'Faça login para continuar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B6B76),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const SizedBox(height: 8),

              const SizedBox(height: 24),
              const Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFF5B800),
                  child: Icon(
                    Icons.handyman_rounded,
                    size: 40,
                    color: Color(0xFF1B2430),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _Input(hint: 'Email', controller: _email),
              const SizedBox(height: 12),
              _Input(
                hint: 'Senha',
                controller: _password,
                password: true,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF9A9AA2),
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B800),
                    foregroundColor: const Color(0xFF1B2430),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _busy ? 'Entrando…' : 'Entrar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },

                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
                      children: [
                        TextSpan(text: 'Ainda não tem uma conta? '),
                        TextSpan(
                          text: 'Cadastre-se',
                          style: TextStyle(
                            color: Color(0xFFF5B800),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 16,
        color: Color(0xFF1B2430),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.hint,
    this.obscure = false,
    this.password = false,
    this.suffixIcon,
    this.controller,
  });

  final String hint;
  final bool obscure;
  final bool password;
  final Widget? suffixIcon;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: !password,
      enableSuggestions: !password,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );
  }
}
