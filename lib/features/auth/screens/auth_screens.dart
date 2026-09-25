import 'package:flutter/material.dart';

class AuthScreens extends StatelessWidget {
  const AuthScreens({super.key});

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
                children: const [
                  _BackButton(),
                  SizedBox(width: 12),
                  Text(
                    'Cadastro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'Criar Conta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2430),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'É rápido e fácil',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B6B76),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFEDEDED),
                  child: Icon(Icons.person, size: 34, color: Color(0xFF1B2430)),
                ),
              ),
              const SizedBox(height: 24),
              const _Input(hint: 'Nome Completo'),
              const SizedBox(height: 12),
              const _Input(hint: 'Email'),
              const SizedBox(height: 12),
              const _Input(hint: 'Telefone'),
              const SizedBox(height: 12),
              const _Input(hint: 'Senha', obscure: true),
              const SizedBox(height: 12),
              const _Input(hint: 'Confirme sua senha', obscure: true),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Icon(Icons.check_box_outline_blank, size: 18, color: Color(0xFF1B2430)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Li e aceito os Termos de Uso e Política de Privacidade',
                      style: TextStyle(color: Color(0xFF6B6B76), fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B800),
                    foregroundColor: const Color(0xFF1B2430),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Começar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Já tem uma conta? Entrar',
                  style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
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
  const _Input({required this.hint, this.obscure = false});

  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
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
