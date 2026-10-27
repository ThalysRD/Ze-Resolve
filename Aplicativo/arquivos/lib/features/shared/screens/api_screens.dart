import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/location/location_service.dart';
import '../../../core/api/chat_client.dart';
import '../../../core/api/notification_client.dart';
import '../../../core/api/push_notifications.dart';
import 'account_settings.dart';
import '../../auth/screens/login/login_screen.dart';
import '../../auth/session/auth_session.dart';
import '../widgets/service_design.dart';
import 'api_widgets.dart';
import 'availability_screen.dart';

export 'api_widgets.dart';
export 'availability_screen.dart';

class LiveProfessionalScreen extends StatefulWidget {
  const LiveProfessionalScreen({super.key, required this.professionalId});
  final int professionalId;
  @override
  State<LiveProfessionalScreen> createState() => _LiveProfessionalScreenState();
}

class _LiveProfessionalScreenState extends State<LiveProfessionalScreen> {
  late Future<Json> _data;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() async => {
    'profile': await api.request(
      'GET',
      '/professionals/${widget.professionalId}',
    ),
    'slots': await api.all(
      '/professionals/${widget.professionalId}/availability',
    ),
  };

  void _reload() => setState(() {
    _data = _load();
  });

  Future<void> _book(Json pro, Json slot) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveRequestForm(professional: pro, slot: slot),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Profissional',
    actions: [
      IconButton(
        tooltip: 'Atualizar agenda',
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: RemoteView<Json>(
      future: _data,
      retry: _reload,
      builder: (data) {
        final pro = Map<String, dynamic>.from(data['profile'] as Map);
        final slots = (data['slots'] as List).cast<Json>();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFFFF3C4),
              child: Text(
                serviceInitials(pro['name'] as String),
                style: const TextStyle(fontSize: 26, color: serviceInk),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pro['name'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${pro['category_name']} · ${pro['city']}'),
            const SizedBox(height: 16),
            ServiceSection(
              title: 'Sobre o profissional',
              icon: Icons.work_outline_rounded,
              children: [Text(pro['bio'] as String)],
            ),
            ServiceSection(
              title: 'Valor da visita',
              icon: Icons.payments_outlined,
              children: [
                Text(
                  visitFeeLabel(pro['visit_fee_cents']),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: serviceInk,
                  ),
                ),
                const Text(
                  'Este valor é da visita. Serviços e materiais adicionais devem ser combinados com o prestador.',
                ),
              ],
            ),
            Text(
              pro['review_count'] == 0
                  ? 'Novo profissional · sem avaliações'
                  : '★ ${pro['rating']} · ${pro['review_count']} avaliações',
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      LiveReviewsScreen(professionalId: widget.professionalId),
                ),
              ),
              child: const Text('Ver avaliações'),
            ),
            const SectionHeading(
              'Agenda disponível',
              subtitle: 'Escolha um horário. O prestador precisa aceitar a solicitação.',
            ),
            if (slots.isEmpty)
              ServiceEmpty(
                title: 'Nenhum horário disponível',
                description: pro['visit_fee_cents'] == null
                    ? 'O prestador ainda precisa definir o valor da visita.'
                    : pro['is_available'] != true
                    ? 'O recebimento de solicitações deste prestador está pausado.'
                    : 'Este prestador ainda não publicou horários livres. Consulte outro profissional ou tente mais tarde.',
                icon: Icons.event_busy_outlined,
              ),
            for (final slot in slots)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        slotLabel(slot),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (!isProfessional) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _book(pro, slot),
                          child: const Text('Escolher este horário'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class LiveRequestForm extends StatefulWidget {
  const LiveRequestForm({
    super.key,
    required this.professional,
    required this.slot,
  });
  final Json professional, slot;
  @override
  State<LiveRequestForm> createState() => _LiveRequestFormState();
}

class _LiveRequestFormState extends State<LiveRequestForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  late Json _professional, _slot;
  Future<Json>? _alternatives;
  bool _busy = false, _conflict = false;

  @override
  void initState() {
    super.initState();
    _professional = {...widget.professional};
    _slot = {...widget.slot};
  }

  @override
  void dispose() {
    for (final controller in [_title, _description, _address]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<Json> _refreshAvailability() async => {
    'profile': await api.request(
      'GET',
      '/professionals/${_professional['id']}',
    ),
    'slots': await api.all(
      '/professionals/${_professional['id']}/availability',
    ),
  };

  void _retryAvailability() => setState(() {
    _alternatives = _refreshAvailability();
  });

  Future<void> _send() async {
    if (_busy || _conflict || !_form.currentState!.validate()) return;
    if (_professional['visit_fee_cents'] == null) {
      notify(context, 'Este prestador ainda não definiu o valor da visita.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await api.request(
        'POST',
        '/requests',
        body: {
          'professional_id': _professional['id'],
          'slot_id': _slot['id'],
          'expected_visit_fee_cents': _professional['visit_fee_cents'],
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'address': _address.text.trim(),
        },
      );
      if (!mounted) return;
      notify(context, 'Solicitação enviada. Aguarde a resposta do prestador.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiveRequestDetails(requestId: result['id'] as int),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        setState(() {
          _conflict = true;
          _alternatives = _refreshAvailability();
        });
      } else {
        notify(context, error);
      }
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Solicitar visita',
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ServiceSection(
            title: '${_professional['name']}',
            icon: Icons.event_available_outlined,
            children: [
              Text(slotLabel(_slot)),
              Text(
                'Valor da visita: ${visitFeeLabel(_professional['visit_fee_cents'])}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Text(
                'O prestador precisa aceitar. A confirmação aparecerá no acompanhamento da solicitação.',
              ),
              const Text(
                'O valor da visita não inclui automaticamente outros serviços ou materiais.',
              ),
            ],
          ),
          if (_conflict) ...[
            const Text(
              'O horário ou o valor da visita mudou. Confira a agenda atualizada e escolha novamente para continuar.',
            ),
            const SizedBox(height: 12),
            RemoteView<Json>(
              future: _alternatives!,
              retry: _retryAvailability,
              builder: (data) {
                final profile = Map<String, dynamic>.from(
                  data['profile'] as Map,
                );
                final slots = (data['slots'] as List).cast<Json>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Valor atual da visita: ${visitFeeLabel(profile['visit_fee_cents'])}',
                    ),
                    if (slots.isEmpty)
                      const Text(
                        'Não há horários livres agora. Você pode voltar e escolher outro prestador.',
                      ),
                    for (final slot in slots)
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _professional = profile;
                          _slot = slot;
                          _conflict = false;
                        }),
                        child: Text(slotLabel(slot)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
          TextFormField(
            controller: _title,
            enabled: !_busy,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Serviço'),
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Descreva o serviço (mínimo 3 caracteres).'
                : null,
          ),
          TextFormField(
            controller: _description,
            enabled: !_busy,
            maxLength: 4000,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrição'),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Informe ao menos 10 caracteres.'
                : null,
          ),
          TextFormField(
            controller: _address,
            enabled: !_busy,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Endereço'),
            validator: (value) => (value?.trim().length ?? 0) < 5
                ? 'Informe o endereço completo.'
                : null,
          ),
          TextButton.icon(
            icon: const Icon(Icons.bookmark_border),
            label: const Text('Escolher endereço salvo'),
            onPressed: _busy
                ? null
                : () async {
                    final address = await Navigator.of(context).push<Json>(
                      MaterialPageRoute(
                        builder: (_) => const AddressesScreen(select: true),
                      ),
                    );
                    if (address != null && mounted) {
                      _address.text = addressLabel(address);
                    }
                  },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy || _conflict ? null : _send,
            child: Text(_busy ? 'Enviando…' : 'Enviar solicitação de visita'),
          ),
        ],
      ),
    ),
  );
}

class LiveRequestsScreen extends StatefulWidget {
  const LiveRequestsScreen({
    super.key,
    this.home = false,
    this.agenda = false,
    this.messages = false,
    this.initialStatus,
  });
  final bool home, agenda, messages;
  final String? initialStatus;
  @override
  State<LiveRequestsScreen> createState() => _LiveRequestsScreenState();
}

class _LiveRequestsScreenState extends State<LiveRequestsScreen> {
  late Future<List<Json>> _data;
  String? _status;
  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _data = _load();
  }

  Future<List<Json>> _load() => api.all(
    '/requests',
    query: _status == null ? null : {'status': _status!},
  );
  void _reload() => setState(() {
    _data = _load();
  });
  Future<void> _open(Json request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.messages
            ? LiveChatScreen(
                requestId: request['id'] as int,
                title: request['title'] as String,
              )
            : LiveRequestDetails(requestId: request['id'] as int),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: widget.home
        ? 'Zé Resolve'
        : widget.agenda
        ? 'Agenda'
        : widget.messages
        ? 'Mensagens'
        : 'Solicitações',
    index: widget.home
        ? 0
        : widget.agenda
        ? 1
        : widget.messages
        ? 3
        : 2,
    actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
    child: RemoteView(
      future: _data,
      retry: _reload,
      builder: (rows) {
        final requests = widget.agenda
            ? rows
                  .where(
                    (r) => ['aceita', 'em_andamento'].contains(r['status']),
                  )
                  .toList()
            : rows;
        if (widget.agenda) {
          requests.sort(
            (a, b) => (a['scheduled_at'] as String).compareTo(
              b['scheduled_at'] as String,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _data;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.home)
                ProfessionalOverview(
                  requests: rows,
                  name: '${AppSession.user?['name'] ?? ''}',
                  open: _open,
                  filter: (status) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveRequestsScreen(initialStatus: status),
                    ),
                  ),
                  profile: () =>
                      Navigator.of(context).pushNamed('/pro-profile'),
                  reviews: () =>
                      Navigator.of(context).pushNamed('/pro-reviews'),
                ),
              if (widget.agenda && isProfessional) ...[
                ServiceSection(
                  title: 'Horários para novas visitas',
                  icon: Icons.calendar_month_outlined,
                  children: [
                    const Text(
                      'Disponibilize os períodos em que pode atender novos clientes.',
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AvailabilityScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Gerenciar meus horários'),
                    ),
                  ],
                ),
              ],
              if (!widget.home)
                SectionHeading(
                  widget.agenda
                      ? 'Seus atendimentos'
                      : widget.messages
                      ? 'Suas conversas'
                      : 'Seus serviços',
                  subtitle: widget.agenda
                      ? 'Acompanhe os horários confirmados.'
                      : widget.messages
                      ? 'Combine os detalhes com cada cliente.'
                      : 'Confira os pedidos e acompanhe cada etapa.',
                ),
              if (!widget.home && !widget.agenda && !widget.messages)
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _status == null,
                      onSelected: (_) {
                        _status = null;
                        _reload();
                      },
                    ),
                    ...statusLabels.entries.map(
                      (entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: _status == entry.key,
                        onSelected: (_) {
                          _status = entry.key;
                          _reload();
                        },
                      ),
                    ),
                  ],
                ),
              if (!widget.home) ...[
                const SizedBox(height: 16),
                if (requests.isEmpty)
                  ServiceEmpty(
                    title: widget.messages
                        ? 'Ainda não há conversas'
                        : widget.agenda
                        ? 'Sua agenda está livre'
                        : 'Nenhum serviço por aqui',
                    description: widget.messages
                        ? 'As conversas dos seus serviços aparecerão aqui.'
                        : widget.agenda
                        ? 'Os serviços confirmados aparecerão na sua agenda.'
                        : 'Novas solicitações aparecerão nesta tela.',
                    icon: widget.messages
                        ? Icons.chat_bubble_outline_rounded
                        : widget.agenda
                        ? Icons.calendar_today_outlined
                        : Icons.assignment_outlined,
                  ),
                ...requests.map(
                  (r) => ServiceRequestCard(
                    request: r,
                    professional: isProfessional,
                    message: widget.messages,
                    onTap: () => _open(r),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class LiveRequestDetails extends StatefulWidget {
  const LiveRequestDetails({super.key, required this.requestId});
  final int requestId;
  @override
  State<LiveRequestDetails> createState() => _LiveRequestDetailsState();
}

class _LiveRequestDetailsState extends State<LiveRequestDetails> {
  late Future<Json> _data;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() async => Map<String, dynamic>.from(
    await api.request('GET', '/requests/${widget.requestId}') as Map,
  );
  void _reload() => setState(() {
    _data = _load();
  });
  Future<void> _transition(String status) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar: ${statusLabels[status]}?'),
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
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await api.request(
        'PATCH',
        '/requests/${widget.requestId}/status',
        body: {'status': status},
      );
      if (!mounted) return;
      setState(() {
        _data = Future.value(Map<String, dynamic>.from(updated as Map));
      });
      notify(context, switch (status) {
        'aceita' => 'Solicitação aceita.',
        'recusada' => 'Solicitação recusada.',
        'em_andamento' => 'Serviço iniciado.',
        'concluida' => 'Serviço concluído.',
        'cancelada' => 'Solicitação cancelada.',
        _ => 'Solicitação atualizada.',
      });
    } catch (error) {
      if (mounted) {
        notify(context, error);
        _reload();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Solicitação #${widget.requestId}',
    actions: [
      IconButton(
        onPressed: _busy ? null : _reload,
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: RemoteView(
      future: _data,
      retry: _reload,
      builder: (r) {
        final transitions = isProfessional
            ? {
                    'pendente': ['aceita', 'recusada'],
                    'aceita': ['em_andamento'],
                    'em_andamento': ['concluida'],
                  }[r['status']] ??
                  <String>[]
            : ['pendente', 'aceita'].contains(r['status'])
            ? ['cancelada']
            : <String>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              r['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ServiceStatus(r['status'] as String),
            ),
            const SizedBox(height: 20),
            ServiceSection(
              title: 'Sobre o serviço',
              icon: Icons.assignment_outlined,
              children: [
                Text(
                  r['description'] as String,
                  style: const TextStyle(
                    color: serviceInk,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                ServiceInfo(
                  icon: Icons.person_outline_rounded,
                  label: isProfessional ? 'Cliente' : 'Prestador de serviço',
                  value:
                      '${r[isProfessional ? 'client_name' : 'professional_name']}',
                ),
              ],
            ),
            ServiceSection(
              title: 'Atendimento',
              icon: Icons.event_available_outlined,
              children: [
                ServiceInfo(
                  icon: Icons.location_on_outlined,
                  label: 'Local do serviço',
                  value: r['address'] as String,
                ),
                ServiceInfo(
                  icon: Icons.calendar_today_outlined,
                  label: 'Data e horário',
                  value: dateLabel(r['scheduled_at']),
                ),
                ServiceInfo(
                  icon: Icons.payments_outlined,
                  label: 'Valor da visita',
                  value: r['visit_fee_cents'] == null
                      ? 'Não informado neste pedido antigo'
                      : visitFeeLabel(r['visit_fee_cents']),
                ),
                if (r['status'] == 'pendente')
                  Text(
                    r['slot_id'] == null
                        ? 'Pedido anterior à agenda publicada. O prestador ainda precisa aceitar.'
                        : 'O horário está reservado enquanto o prestador decide se aceita a solicitação.',
                  ),
                ServiceInfo(
                  icon: Icons.schedule_outlined,
                  label: 'Tempo reservado',
                  value: '${r['duration_minutes']} minutos',
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...transitions.map(
              (target) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  onPressed: _busy ? null : () => _transition(target),
                  child: Text(
                    _busy
                        ? 'Aguardando confirmação…'
                        : switch (target) {
                            'aceita' => 'Aceitar solicitação',
                            'recusada' => 'Recusar solicitação',
                            'em_andamento' => 'Iniciar serviço',
                            'concluida' => 'Concluir serviço',
                            _ => 'Cancelar solicitação',
                          },
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LiveChatScreen(
                    requestId: widget.requestId,
                    title: r['title'] as String,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Conversar'),
            ),
            if (!isProfessional && r['status'] == 'concluida')
              FilledButton(
                onPressed: r['review_id'] != null
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LiveRateScreen(requestId: widget.requestId),
                          ),
                        );
                        if (mounted) _reload();
                      },
                child: Text(
                  r['review_id'] != null
                      ? 'Serviço já avaliado'
                      : 'Avaliar serviço',
                ),
              ),
          ],
        );
      },
    ),
  );
}

class LiveRateScreen extends StatefulWidget {
  const LiveRateScreen({super.key, required this.requestId});
  final int requestId;
  @override
  State<LiveRateScreen> createState() => _LiveRateScreenState();
}

class _LiveRateScreenState extends State<LiveRateScreen> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await api.request(
        'POST',
        '/requests/${widget.requestId}/review',
        body: {'rating': _rating, 'comment': _comment.text},
      );
      if (!mounted) return;
      notify(context, 'Avaliação enviada.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Avaliar serviço',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<int>(
          initialValue: _rating,
          decoration: const InputDecoration(labelText: 'Nota'),
          items: List.generate(
            5,
            (i) => DropdownMenuItem(
              value: i + 1,
              child: Text('${i + 1} estrelas'),
            ),
          ),
          onChanged: _busy ? null : (value) => setState(() => _rating = value!),
        ),
        TextField(
          controller: _comment,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Como foi o serviço?'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Salvando…' : 'Enviar avaliação'),
        ),
      ],
    ),
  );
}

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({
    super.key,
    required this.requestId,
    required this.title,
  });
  final int requestId;
  final String title;
  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final _body = TextEditingController();
  late final ChatClient _chat;
  String? _pendingId, _pendingBody;
  bool _busy = false;
  final _reading = <int>{};
  @override
  void initState() {
    super.initState();
    NotificationClient.instance.activeRequestId = widget.requestId;
    _chat = ChatClient(widget.requestId);
    _chat.addListener(_changed);
    _chat.connect();
  }

  void _changed() {
    for (final message in _chat.messages) {
      final id = message['id'] as int;
      if (message['sender_id'] != AppSession.user?['id'] && _reading.add(id)) {
        unawaited(
          NotificationClient.instance.markRead(id).catchError((Object _) {
            _reading.remove(id);
          }),
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chat.removeListener(_changed);
    if (NotificationClient.instance.activeRequestId == widget.requestId) {
      NotificationClient.instance.activeRequestId = null;
    }
    _chat.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) return;
    if (_pendingId == null || _pendingBody != _body.text) {
      final random = Random.secure();
      _pendingId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _pendingBody = _body.text;
    }
    setState(() => _busy = true);
    try {
      await _chat.send(_body.text, _pendingId!);
      if (!mounted) return;
      _body.clear();
      _pendingId = null;
      _pendingBody = null;
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: widget.title,
    actions: [
      IconButton(
        onPressed: _chat.connecting ? null : _chat.connect,
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: Column(
      children: [
        if (_chat.connecting) const LinearProgressIndicator(),
        if (_chat.error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(_chat.error!),
                TextButton(
                  onPressed: _chat.connect,
                  child: const Text('Reconectar'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _chat.messages.isEmpty
              ? Center(
                  child: Text(
                    _chat.connecting
                        ? 'Conectando ao chat…'
                        : _chat.connected
                        ? 'Inicie a conversa sobre este serviço.'
                        : 'Suas mensagens aparecerão aqui quando a conversa estiver conectada.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _chat.messages.map((message) {
                    final mine = message['sender_id'] == AppSession.user?['id'];
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        color: mine ? const Color(0xFFFFF3C4) : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message['body'] as String),
                              const SizedBox(height: 4),
                              Text(
                                dateLabel(message['created_at']),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _body,
                  enabled: !_busy,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: _busy || !_chat.connected ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LiveReviewsScreen extends StatefulWidget {
  const LiveReviewsScreen({super.key, this.professionalId});
  final int? professionalId;
  @override
  State<LiveReviewsScreen> createState() => _LiveReviewsScreenState();
}

class _LiveReviewsScreenState extends State<LiveReviewsScreen> {
  late Future<List<Json>> _data;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<List<Json>> _load() async {
    try {
      return await api.all(
        '/professionals/${widget.professionalId ?? AppSession.user?['id']}/reviews',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404 && widget.professionalId == null) return [];
      rethrow;
    }
  }

  void _reload() => setState(() {
    _data = _load();
  });
  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Avaliações',
    actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
    child: RemoteView(
      future: _data,
      retry: _reload,
      builder: (reviews) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeading(
            'Experiências de quem contratou',
            subtitle: 'Avaliações de serviços concluídos pelo aplicativo.',
          ),
          if (reviews.isEmpty)
            ServiceEmpty(
              title: widget.professionalId == null && isProfessional
                  ? 'Sua história começa aqui'
                  : 'Ainda não há avaliações',
              description: 'As avaliações aparecerão depois que os clientes avaliarem os serviços concluídos.',
              icon: Icons.star_border_rounded,
            ),
          ...reviews.map((review) => ServiceReviewCard(review: review)),
        ],
      ),
    ),
  );
}

class LiveAccountScreen extends StatefulWidget {
  const LiveAccountScreen({super.key});
  @override
  State<LiveAccountScreen> createState() => _LiveAccountScreenState();
}

class _LiveAccountScreenState extends State<LiveAccountScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  final _bio = TextEditingController(), _city = TextEditingController();
  final _price = TextEditingController();
  int? _category;
  double? _latitude, _longitude;
  bool _available = false;
  Json? _savedProfile;
  bool _busy = false;
  late Future<List<Json>> _data;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<List<Json>> _load() async {
    final sessionToken = api.token;
    final user = Map<String, dynamic>.from(
      await api.request('GET', '/users/me') as Map,
    );
    if (!mounted || api.token != sessionToken) return [];
    AppSession.user = user;
    _name.text = user['name'] as String;
    _phone.text = user['phone'] as String;
    if (!isProfessional) return [];
    final categories = await api.list('/categories');
    if (!mounted || api.token != sessionToken) return categories;
    try {
      final pro = await api.request('GET', '/professionals/me');
      if (!mounted || api.token != sessionToken) return categories;
      _category = pro['category_id'] as int;
      _latitude = (pro['latitude'] as num?)?.toDouble();
      _longitude = (pro['longitude'] as num?)?.toDouble();
      _available = pro['is_available'] as bool;
      _savedProfile = {
        for (final key in [
          'category_id',
          'bio',
          'city',
          'visit_fee_cents',
          'latitude',
          'longitude',
          'is_available',
        ])
          key: pro[key],
      };
      _bio.text = pro['bio'] as String;
      _city.text = pro['city'] as String;
      _price.text = pro['visit_fee_cents'] == null
          ? ''
          : ((pro['visit_fee_cents'] as num) / 100).toStringAsFixed(2);
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      if (!mounted || api.token != sessionToken) return categories;
      _category = null;
      _city.clear();
      _price.clear();
      _bio.clear();
      _latitude = _longitude = null;
      _available = false;
      _savedProfile = null;
    }
    return categories;
  }

  void _reload() => setState(() {
    _data = _load();
  });
  @override
  void dispose() {
    for (final c in [_name, _phone, _bio, _city, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAccount() async {
    final sessionToken = api.token;
    setState(() => _busy = true);
    try {
      final user = await api.request(
        'PATCH',
        '/users/me',
        body: {'name': _name.text, 'phone': _phone.text},
      );
      if (!mounted || api.token != sessionToken) return;
      AppSession.user = Map<String, dynamic>.from(user as Map);
      if (mounted) notify(context, 'Dados pessoais salvos.');
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfessional() async {
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    if (price == null || !price.isFinite || price < 0 || _category == null) {
      notify(context, 'Informe uma categoria e um valor válido para a visita.');
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = <String, dynamic>{
        'category_id': _category,
        'bio': _bio.text,
        'city': _city.text,
        'visit_fee_cents': (price * 100).round(),
        'latitude': _latitude,
        'longitude': _longitude,
        'is_available': _available,
      };
      final saved = await api.request(
        'PUT',
        '/professionals/me',
        body: profile,
      );
      if (!mounted) return;
      setState(() {
        _available = saved['is_available'] as bool;
        _savedProfile = {...profile, 'is_available': _available};
      });
      notify(context, 'Perfil profissional salvo.');
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAvailability(bool value) async {
    if (_savedProfile == null) return;
    setState(() => _busy = true);
    try {
      final profile = {..._savedProfile!, 'is_available': value};
      final saved = await api.request(
        'PUT',
        '/professionals/me',
        body: profile,
      );
      if (!mounted) return;
      setState(() {
        _available = saved['is_available'] as bool;
        _savedProfile = {...profile, 'is_available': _available};
      });
      notify(
        context,
        _available
            ? 'Seus horários publicados podem receber solicitações.'
            : 'O recebimento de novas solicitações está pausado.',
      );
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await AppSession.revoke();
      if (!mounted) return;
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
    title: 'Meu perfil',
    index: 4,
    child: RemoteView(
      future: _data,
      retry: _reload,
      builder: (categories) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFFFF3C4),
                    child: Text(
                      serviceInitials(_name.text),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: serviceInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _name.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: serviceInk,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${AppSession.user?['email']}',
                    style: const TextStyle(fontSize: 13, color: serviceMuted),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3C4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isProfessional ? 'Prestador de serviço' : 'Cliente',
                      style: const TextStyle(
                        fontSize: 12,
                        color: serviceInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ServiceSection(
            title: 'Dados pessoais',
            icon: Icons.person_outline_rounded,
            children: [
              TextField(
                controller: _name,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Nome do cadastro',
                ),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _saveAccount,
                child: const Text('Salvar dados pessoais'),
              ),
            ],
          ),
          ServiceSection(
            title: 'Sua conta',
            icon: Icons.settings_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Meus endereços'),
                subtitle: const Text(
                  'Casa, trabalho e outros locais de atendimento',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddressesScreen(),
                        ),
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Alterar senha'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      ),
              ),
              ListenableBuilder(
                listenable: PushNotifications.instance,
                builder: (_, _) => ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notificações de mensagens'),
                  subtitle: Text(PushNotifications.instance.status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy
                      ? null
                      : () => PushNotifications.instance.start(
                          AppSession.user!['id'] as int,
                          requestPermission: true,
                        ),
                ),
              ),
            ],
          ),
          if (isProfessional) ...[
            ServiceSection(
              title: 'Meu trabalho',
              icon: Icons.work_outline_rounded,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Especialidade'),
                  items: categories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat['id'] as int,
                          child: Text(cat['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _category = value),
                ),
                TextField(
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Sobre mim e meus serviços',
                    helperText: 'Se quiser, descreva aqui sua tabela de preços de serviços.',
                    helperMaxLines: 3,
                  ),
                ),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'Cidade e UF'),
                ),
                TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor fixo da visita (R\$)',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Receber solicitações pela agenda'),
                  value: _available,
                  subtitle: Text(
                    _savedProfile == null
                        ? 'Salve seu perfil profissional para ativar novas solicitações.'
                        : _savedProfile?['visit_fee_cents'] == null
                        ? 'Defina e salve o valor da visita para ativar sua agenda.'
                        : _available
                        ? 'Clientes podem solicitar seus horários publicados e livres.'
                        : 'Ative quando estiver pronto para novos atendimentos.',
                  ),
                  onChanged:
                      _busy ||
                          _savedProfile == null ||
                          _savedProfile?['visit_fee_cents'] == null
                      ? null
                      : _setAvailability,
                ),
                OutlinedButton.icon(
                  onPressed:
                      _busy ||
                          _savedProfile == null ||
                          _savedProfile?['visit_fee_cents'] == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AvailabilityScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Gerenciar meus horários'),
                ),
                Text(
                  _latitude == null
                      ? 'Cadastre sua base para aparecer nas buscas por proximidade.'
                      : 'Base de atendimento cadastrada. Apenas a distância é pública.',
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('Usar localização atual como base'),
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() {
                            _busy = true;
                          });
                          try {
                            final p = await LocationService.current();
                            if (mounted) {
                              setState(() {
                                _latitude = p.latitude;
                                _longitude = p.longitude;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) notify(context, e);
                          } finally {
                            if (mounted) {
                              setState(() {
                                _busy = false;
                              });
                            }
                          }
                        },
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _latitude = null;
                          _longitude = null;
                        }),
                  child: const Text('Desativar busca por proximidade'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _saveProfessional,
                  child: const Text('Salvar perfil profissional'),
                ),
              ],
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _busy ? null : _logout,
            child: const Text('Sair da conta'),
          ),
        ],
      ),
    ),
  );
}
