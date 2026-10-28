import 'package:flutter/material.dart';

import '../../auth/screens/login/login_screen.dart';
import '../../auth/session/auth_session.dart';
import 'api_widgets.dart';

const currentTermsVersion = '2026-10-25';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) => ApiPage(
    title: kind == 'privacy' ? 'Privacidade' : 'Termos de uso',
    child: _LegalDocument(kind: kind),
  );
}

class _LegalDocument extends StatefulWidget {
  const _LegalDocument({required this.kind});
  final String kind;
  @override
  State<_LegalDocument> createState() => _LegalDocumentState();
}

class _LegalDocumentState extends State<_LegalDocument> {
  late Future<dynamic> _data;
  @override
  void initState() {
    super.initState();
    _data = api.request('GET', '/legal/documents/${widget.kind}');
  }

  @override
  Widget build(BuildContext context) => RemoteView(
    future: _data,
    retry: () => setState(() {
      _data = api.request('GET', '/legal/documents/${widget.kind}');
    }),
    builder: (item) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          item['title'] as String,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Versão ${item['version']}'),
        const SizedBox(height: 20),
        SelectableText(
          item['body'] as String,
          style: const TextStyle(height: 1.6),
        ),
        const SizedBox(height: 20),
        SelectableText('Contato: ${item['contact']}'),
      ],
    ),
  );
}

class AccountAccessScreen extends StatefulWidget {
  const AccountAccessScreen({
    super.key,
    this.verifyEmail = false,
    this.email = '',
  });
  final bool verifyEmail;
  final String email;
  @override
  State<AccountAccessScreen> createState() => _AccountAccessScreenState();
}

class _AccountAccessScreenState extends State<AccountAccessScreen> {
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _requested = false;
  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _request() async {
    if (_email.text.trim().isEmpty) {
      notify(context, 'Informe seu email.');
      return;
    }
    setState(() => _busy = true);
    try {
      await api.request(
        'POST',
        widget.verifyEmail
            ? '/auth/email/verification-request'
            : '/auth/password/reset-request',
        body: {'email': _email.text.trim()},
      );
      if (!mounted) return;
      setState(() => _requested = true);
      notify(
        context,
        'Solicitação recebida. Se a conta estiver disponível, o código chegará por email.',
      );
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (!RegExp(r'^\d{8}$').hasMatch(_code.text.trim())) {
      notify(context, 'Informe o código de 8 dígitos recebido por email.');
      return;
    }
    if (!widget.verifyEmail &&
        (_password.text.length < 8 || _password.text != _confirm.text)) {
      notify(context, 'Use pelo menos 8 caracteres e confirme a nova senha.');
      return;
    }
    setState(() => _busy = true);
    try {
      await api.request(
        'POST',
        widget.verifyEmail ? '/auth/email/verify' : '/auth/password/reset',
        body: {
          'email': _email.text.trim(),
          'code': _code.text.trim(),
          if (!widget.verifyEmail) 'new_password': _password.text,
        },
      );
      if (!mounted) return;
      notify(
        context,
        widget.verifyEmail
            ? 'Email confirmado. Entre na sua conta.'
            : 'Senha alterada. Entre novamente.',
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: widget.verifyEmail ? 'Confirmar email' : 'Recuperar acesso',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.verifyEmail
              ? 'Confirme seu endereço de email para proteger sua conta.'
              : 'Receba um código para criar uma nova senha. Sua senha atual não será enviada por email.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _request,
          child: Text(_requested ? 'Solicitar novo código' : 'Receber código'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'Código recebido por email',
            helperText: 'Válido por 15 minutos.',
          ),
        ),
        if (!widget.verifyEmail) ...[
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Nova senha'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Confirmar nova senha',
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _finish,
          child: Text(
            _busy
                ? 'Aguarde…'
                : widget.verifyEmail
                ? 'Confirmar email'
                : 'Salvar nova senha',
          ),
        ),
      ],
    ),
  );
}

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _password = TextEditingController();
  late Future<dynamic> _sessions;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _sessions = api.request('GET', '/users/me/sessions');
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _act(bool close) async {
    if (_password.text.isEmpty) {
      notify(context, 'Informe sua senha atual.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          close ? 'Encerrar sua conta?' : 'Sair de todos os dispositivos?',
        ),
        content: Text(
          close
              ? 'O perfil será desativado, as reservas serão canceladas e os campos pessoais próprios serão removidos. O histórico conserva datas, valores e estados sem sua identificação nesses campos. Esta ação não pode ser desfeita.'
              : 'Você precisará entrar novamente em todos os dispositivos, inclusive neste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.request(
        'POST',
        close ? '/users/me/closure' : '/users/me/sessions/revoke-all',
        body: {'password': _password.text},
      );
      AppSession.logout();
      await AppSession.deleteStoredSession();
      if (!mounted) return;
      notify(
        context,
        close
            ? 'Sua conta foi encerrada.'
            : 'Todas as sessões foram encerradas.',
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Segurança da conta',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        RemoteView(
          future: _sessions,
          retry: () => setState(() {
            _sessions = api.request('GET', '/users/me/sessions');
          }),
          builder: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sessões recentes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final row in (rows as List).take(20))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Acesso em ${dateLabel(row['issued_at'])}'),
                  subtitle: Text(
                    row['revoked'] == true
                        ? 'Sessão encerrada'
                        : 'Validade até ${dateLabel(row['expires_at'])}',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _password,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Senha atual para confirmar',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _busy ? null : () => _act(false),
          child: const Text('Sair de todos os dispositivos'),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LegalDocumentScreen(kind: 'privacy'),
            ),
          ),
          child: const Text('Como meus dados são tratados'),
        ),
        const Divider(height: 32),
        TextButton(
          onPressed: _busy ? null : () => _act(true),
          child: const Text(
            'Encerrar minha conta',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}
