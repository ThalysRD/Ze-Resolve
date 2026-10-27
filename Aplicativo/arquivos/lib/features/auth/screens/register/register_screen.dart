import 'package:flutter/material.dart';

import '../login/login_screen.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/errors/user_message.dart';
import '../../session/auth_session.dart';
import '../../../client/screens/home_client_screen.dart';
import '../../../professional/screens/home_professional_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;
  bool _busy = false;
  String _role = 'cliente';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_termsAccepted || _password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aceite os termos e confirme a senha corretamente.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.request(
        'POST',
        '/auth/register',
        body: {
          'name': _name.text,
          'email': _email.text.trim(),
          'phone': _phone.text,
          'password': _password.text,
          'role': _role,
        },
      );
      // O cadastro confirmado permanece válido mesmo se o login seguinte falhar.
      try {
        await AppSession.login(_email.text, _password.text);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada. Entre com seu email e senha.'),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => _role == 'cliente'
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
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Criar Conta',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      Text(
                        'É rápido e fácil',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B6B76),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Center(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDEDED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 50,
                        color: Color(0xFF9A9AA2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adicionar foto (opcional)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A9AA2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _Input(hint: 'Nome Completo', controller: _name),
              const SizedBox(height: 12),
              _Input(hint: 'Email', controller: _email),
              const SizedBox(height: 12),
              _Input(hint: 'Telefone', controller: _phone),
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
              const SizedBox(height: 12),

              _Input(
                hint: 'Confirme sua senha',
                controller: _confirm,
                password: true,
                obscure: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF9A9AA2),
                  ),
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Como você vai usar o app?',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'cliente',
                    child: Text('Quero contratar serviços'),
                  ),
                  DropdownMenuItem(
                    value: 'profissional',
                    child: Text('Quero oferecer serviços'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _role = value!),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () {
                  setState(() => _termsAccepted = !_termsAccepted);
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      _termsAccepted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: const Color(0xFF1B2430),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Li e aceito os Termos de Uso e Política de Privacidade',
                        style: TextStyle(
                          color: Color(0xFF6B6B76),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B800),
                    foregroundColor: const Color(0xFF1B2430),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _busy ? 'Criando conta…' : 'Começar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
                      children: [
                        TextSpan(text: 'Já tem uma conta? '),
                        TextSpan(
                          text: 'Entrar',
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
              const SizedBox(height: 24),
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
        hintStyle: const TextStyle(color: Color(0xFFAFAFAF), fontSize: 14),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF5B800)),
        ),
      ),
    );
  }
}
