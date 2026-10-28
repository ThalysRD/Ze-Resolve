import 'package:flutter/material.dart';

import '../../auth/session/auth_session.dart';
import '../../auth/screens/login/login_screen.dart';
import 'api_screens.dart';

String addressLabel(Json a) =>
    '${a['street']}, ${a['number']}'
    '${a['complement'] == '' ? '' : ', ${a['complement']}'}'
    ' · ${a['neighborhood']} · ${a['city']}/${a['state']} · CEP ${a['postal_code']}';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.select = false});
  final bool select;
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late Future<List<Json>> _data;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _data = api.list('/users/me/addresses');
  }

  void _reload() => setState(() {
    _data = api.list('/users/me/addresses');
  });
  Future<void> _edit([Json? address]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddressEditor(address: address)),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _archive(Json address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remover dos meus endereços?'),
        content: const Text(
          'Os serviços já solicitados continuam com o endereço combinado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.request('POST', '/users/me/addresses/${address['id']}/archive');
      if (mounted) {
        notify(context, 'Endereço removido da lista.');
        _reload();
      }
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Meus endereços',
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Adicionar endereço'),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: RemoteView(
            future: _data,
            retry: _reload,
            builder: (rows) => rows.isEmpty
                ? const Center(
                    child: Text(
                      'Salve um endereço para facilitar suas solicitações.',
                    ),
                  )
                : ListView(
                    children: rows
                        .map(
                          (a) => Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.location_on_outlined,
                                  ),
                                  title: Text(
                                    '${a['label']}${a['is_default'] == true ? ' · Padrão' : ''}',
                                  ),
                                  subtitle: Text(addressLabel(a)),
                                  onTap: _busy
                                      ? null
                                      : () => widget.select
                                            ? Navigator.pop(context, a)
                                            : _edit(a),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _busy ? null : () => _edit(a),
                                      child: const Text('Editar'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _archive(a),
                                      child: const Text('Remover'),
                                    ),
                                    if (widget.select)
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => Navigator.pop(context, a),
                                        child: const Text('Usar endereço'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    ),
  );
}

class AddressEditor extends StatefulWidget {
  const AddressEditor({super.key, this.address});
  final Json? address;
  @override
  State<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<AddressEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool _default = false, _busy = false;
  static const fields = {
    'label': ('Apelido (Casa, Trabalho…)', 40),
    'postal_code': ('CEP', 8),
    'street': ('Rua ou avenida', 120),
    'number': ('Número ou S/N', 20),
    'complement': ('Complemento (opcional)', 80),
    'neighborhood': ('Bairro', 80),
    'city': ('Cidade', 80),
    'state': ('UF', 2),
  };
  @override
  void initState() {
    super.initState();
    for (final key in fields.keys) {
      _controllers[key] = TextEditingController(
        text: widget.address?[key] as String? ?? '',
      );
    }
    _default = widget.address?['is_default'] == true;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await api.request(
        widget.address == null ? 'POST' : 'PUT',
        '/users/me/addresses${widget.address == null ? '' : '/${widget.address!['id']}'}',
        body: {
          for (final e in _controllers.entries)
            e.key: e.key == 'state'
                ? e.value.text.trim().toUpperCase()
                : e.value.text.trim(),
          'is_default': _default,
        },
      );
      if (mounted) {
        notify(context, 'Endereço salvo.');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: widget.address == null ? 'Adicionar endereço' : 'Editar endereço',
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...fields.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _controllers[e.key],
                enabled: !_busy,
                maxLength: e.value.$2,
                keyboardType: e.key == 'postal_code'
                    ? TextInputType.number
                    : TextInputType.streetAddress,
                textCapitalization: e.key == 'state'
                    ? TextCapitalization.characters
                    : TextCapitalization.words,
                decoration: InputDecoration(labelText: e.value.$1),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (e.key == 'complement') {
                    return null;
                  }
                  if (e.key == 'postal_code') {
                    return RegExp(r'^[0-9]{8}$').hasMatch(value)
                        ? null
                        : 'Informe os 8 dígitos do CEP.';
                  }
                  if (value.length < (e.key == 'number' ? 1 : 2)) {
                    return 'Preencha este campo.';
                  }
                  return null;
                },
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Usar como endereço padrão'),
            value: _default,
            onChanged: _busy ? null : (v) => setState(() => _default = v),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Salvando…' : 'Salvar endereço'),
          ),
        ],
      ),
    ),
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _new = TextEditingController(),
      _confirmation = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await api.request(
        'POST',
        '/users/me/password',
        body: {'current_password': _current.text, 'new_password': _new.text},
      );
      AppSession.logout();
      await AppSession.deleteStoredSession().catchError((Object _) {});
      if (!mounted) return;
      notify(context, 'Senha alterada. Entre com sua nova senha.');
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
    title: 'Alterar senha',
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Use uma senha com pelo menos 8 caracteres. Após a alteração, você precisará entrar novamente nos seus dispositivos.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _current,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Senha atual'),
            validator: (v) =>
                (v ?? '').isEmpty ? 'Informe sua senha atual.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _new,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Nova senha'),
            validator: (v) =>
                (v ?? '').length < 8 ? 'Use pelo menos 8 caracteres.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Confirmar nova senha',
            ),
            validator: (v) =>
                v != _new.text ? 'As senhas não coincidem.' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Alterando…' : 'Alterar senha'),
          ),
        ],
      ),
    ),
  );
}
