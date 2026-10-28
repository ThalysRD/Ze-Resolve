import 'package:flutter/material.dart';

import 'api_widgets.dart';
import '../widgets/service_design.dart';

String slotLabel(Json slot) {
  final start = DateTime.parse(slot['starts_at'] as String).toLocal();
  final end = DateTime.parse(slot['ends_at'] as String).toLocal();
  if (start.year != end.year ||
      start.month != end.month ||
      start.day != end.day) {
    return '${dateLabel(slot['starts_at'])} até ${dateLabel(slot['ends_at'])}';
  }
  final hour = '${end.hour}'.padLeft(2, '0');
  final minute = '${end.minute}'.padLeft(2, '0');
  return '${dateLabel(slot['starts_at'])} até $hour:$minute';
}

String visitFeeLabel(dynamic cents) =>
    cents == null ? 'Valor da visita a definir' : money(cents);

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late Future<Json> _data;
  int? _archiving;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() async => {
    'profile': await api.request('GET', '/professionals/me'),
    'slots': await api.all('/professionals/me/availability'),
  };

  void _reload() => setState(() {
    _data = _load();
  });

  Future<void> _publish() async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PublishAvailabilityScreen()),
    );
    if (published == true && mounted) _reload();
  }

  Future<void> _archive(Json slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar este horário?'),
        content: Text(slotLabel(slot)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Manter'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar horário'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _archiving = slot['id'] as int);
    try {
      await api.request(
        'POST',
        '/professionals/me/availability/${slot['id']}/archive',
      );
      if (!mounted) return;
      notify(context, 'Horário retirado da agenda.');
      _reload();
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _archiving = null);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Meus horários',
    actions: [
      IconButton(
        tooltip: 'Atualizar agenda',
        onPressed: _archiving == null ? _reload : null,
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: RemoteView<Json>(
      future: _data,
      retry: _reload,
      builder: (data) {
        final profile = data['profile'] as Map;
        final slots = (data['slots'] as List).cast<Json>();
        final upcoming =
            slots
                .where(
                  (slot) =>
                      slot['is_active'] == true &&
                      DateTime.parse(slot['starts_at'] as String)
                          .isAfter(DateTime.now()),
                )
                .toList()
              ..sort(
                (a, b) => (a['starts_at'] as String).compareTo(
                  b['starts_at'] as String,
                ),
              );
        final canPublish = profile['visit_fee_cents'] != null;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ServiceSection(
              title: 'Sua agenda de visitas',
              icon: Icons.event_available_outlined,
              children: [
                Text(
                  'Valor da visita: ${visitFeeLabel(profile['visit_fee_cents'])}',
                ),
                const Text(
                  'Publique um horário por atendimento. A solicitação reserva o horário enquanto você decide se aceita.',
                ),
                if (profile['is_available'] != true)
                  const Text(
                    'O recebimento de solicitações está pausado. Ative no perfil para exibir seus horários aos clientes.',
                  ),
                if (!canPublish)
                  const Text(
                    'Defina o valor da visita no seu perfil antes de publicar horários.',
                  ),
                FilledButton.icon(
                  onPressed: canPublish && _archiving == null ? _publish : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Disponibilizar horário'),
                ),
              ],
            ),
            const SectionHeading('Próximos horários'),
            if (upcoming.isEmpty)
              const ServiceEmpty(
                title: 'Nenhum horário publicado',
                description: 'Disponibilize os períodos em que pode realizar atendimentos.',
                icon: Icons.calendar_month_outlined,
              ),
            for (final slot in upcoming)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slotLabel(slot),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slot['is_booked'] == true
                            ? 'Reservado · acompanhe a solicitação recebida'
                            : 'Livre para uma solicitação',
                      ),
                      if (slot['is_booked'] != true)
                        TextButton.icon(
                          onPressed: _archiving == null
                              ? () => _archive(slot)
                              : null,
                          icon: const Icon(Icons.event_busy_outlined),
                          label: Text(
                            _archiving == slot['id']
                                ? 'Retirando…'
                                : 'Retirar horário',
                          ),
                        ),
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

class PublishAvailabilityScreen extends StatefulWidget {
  const PublishAvailabilityScreen({super.key});

  @override
  State<PublishAvailabilityScreen> createState() =>
      _PublishAvailabilityScreenState();
}

class _PublishAvailabilityScreenState extends State<PublishAvailabilityScreen> {
  DateTime? _start, _end;
  bool _busy = false;

  Future<void> _pick({required bool end}) async {
    final now = DateTime.now();
    final selected =
        (end ? _end ?? _start : _start) ?? now.add(const Duration(hours: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: selected.isBefore(now) ? now : selected,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (!mounted || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selected),
    );
    if (!mounted || time == null) return;
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (end) {
        _end = value;
      } else {
        _start = value;
        _end = value.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _save() async {
    final start = _start, end = _end;
    if (start == null || end == null || !start.isAfter(DateTime.now())) {
      notify(context, 'Escolha início e término futuros para a visita.');
      return;
    }
    final minutes = end.difference(start).inMinutes;
    if (minutes < 30 || minutes > 480) {
      notify(context, 'O horário precisa ter entre 30 minutos e 8 horas.');
      return;
    }
    setState(() => _busy = true);
    try {
      await api.request(
        'POST',
        '/professionals/me/availability',
        body: {
          'starts_at': start.toUtc().toIso8601String(),
          'ends_at': end.toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      notify(context, 'Horário disponibilizado.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) notify(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ApiPage(
    title: 'Disponibilizar horário',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const ServiceSection(
          title: 'Uma visita por horário',
          icon: Icons.schedule_outlined,
          children: [
            Text(
              'Escolha o período completo para atender um cliente, entre 30 minutos e 8 horas. Horários sobrepostos não podem ser publicados.',
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _pick(end: false),
          icon: const Icon(Icons.event_outlined),
          label: Text(
            _start == null
                ? 'Escolher início'
                : 'Início: ${dateLabel(_start!.toIso8601String())}',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy || _start == null ? null : () => _pick(end: true),
          icon: const Icon(Icons.schedule),
          label: Text(
            _end == null
                ? 'Escolher término'
                : 'Término: ${dateLabel(_end!.toIso8601String())}',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Publicando…' : 'Publicar horário'),
        ),
      ],
    ),
  );
}
