import 'package:flutter/material.dart';

import '../register/register_screen.dart';
import '../../session/auth_session.dart';
import '../../../client/screens/home_client_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    crossAxisAlignment: CrossAxisAlignment.start, // Alinha os textos à esquerda
                    children: [
                      Text(
                        'Bem vindo de volta!',
                        style: TextStyle(
                          fontSize: 28,
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
                  radius: 38,
                  backgroundColor: Color(0xFFF5B800),
                  child: Icon(Icons.handyman_rounded, size: 40, color: Color(0xFF1B2430)),
                ),
              ),
              const SizedBox(height: 26),
              const _Input(hint: 'Email'),
              const SizedBox(height: 12),
              _Input(
                hint: 'Senha',
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
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Esqueci minha senha',
                    style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    AppSession.login('cliente');

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeClientScreen()),
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B800),
                    foregroundColor: const Color(0xFF1B2430),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 350),

              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },

                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: Color(0xFF6B6B76),
                        fontSize: 12,
                      ),
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
      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1B2430)),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.hint,
    this.obscure = false,
    this.suffixIcon,
  });

  final String hint;
  final bool obscure;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
