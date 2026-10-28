import 'package:flutter/material.dart';

const serviceInk = Color(0xFF1B2430);
const serviceMuted = Color(0xFF7C7C80);
const serviceYellow = Color(0xFFF5B800);

String serviceInitials(String name) => name
    .split(' ')
    .where((s) => s.isNotEmpty)
    .take(2)
    .map((s) => s[0])
    .join()
    .toUpperCase();
String serviceDate(dynamic value) {
  final d = DateTime.parse(value as String).toLocal();
  String pad(int n) => '$n'.padLeft(2, '0');
  return '${pad(d.day)}/${pad(d.month)} · ${pad(d.hour)}:${pad(d.minute)}';
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: serviceInk,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 13, color: serviceMuted),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class ServiceSection extends StatelessWidget {
  const ServiceSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: serviceYellow, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: serviceInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class ServiceStatus extends StatelessWidget {
  const ServiceStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (label, ink, background) = switch (status) {
      'pendente' => (
        'Aguardando resposta',
        const Color(0xFF8B6500),
        const Color(0xFFFFF3C4),
      ),
      'aceita' => (
        'Confirmado',
        const Color(0xFF237147),
        const Color(0xFFEAF6EF),
      ),
      'em_andamento' => (
        'Em andamento',
        const Color(0xFF2F60A0),
        const Color(0xFFEBF2FF),
      ),
      'concluida' => (
        'Concluído',
        const Color(0xFF237147),
        const Color(0xFFEAF6EF),
      ),
      'recusada' => (
        'Recusado',
        const Color(0xFF9C4444),
        const Color(0xFFFCEEEE),
      ),
      _ => ('Cancelado', serviceMuted, const Color(0xFFF0F0F2)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ink),
      ),
    );
  }
}

class ServiceRequestCard extends StatelessWidget {
  const ServiceRequestCard({
    super.key,
    required this.request,
    required this.professional,
    required this.onTap,
    this.message = false,
  });
  final Map<String, dynamic> request;
  final bool professional, message;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final name =
        '${request[professional ? 'client_name' : 'professional_name']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: const Color(0xFFFFF3C4),
                    child: Text(
                      serviceInitials(name),
                      style: const TextStyle(
                        color: serviceInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: serviceInk,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          professional ? 'Cliente' : 'Prestador de serviço',
                          style: const TextStyle(
                            fontSize: 12,
                            color: serviceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    message
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.chevron_right,
                    color: serviceMuted,
                    size: 21,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${request['title']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: serviceInk,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final date = Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: serviceMuted,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          serviceDate(request['scheduled_at']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: serviceMuted,
                          ),
                        ),
                      ),
                    ],
                  );
                  final status = ServiceStatus('${request['status']}');
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(12) > 15) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [date, const SizedBox(height: 10), status],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: date),
                      status,
                    ],
                  );
                },
              ),
              if (message) ...[
                const SizedBox(height: 12),
                const Text(
                  'Abrir conversa sobre este serviço',
                  style: TextStyle(fontSize: 12, color: serviceMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceEmpty extends StatelessWidget {
  const ServiceEmpty({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.assignment_outlined,
  });
  final String title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3C4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: serviceInk),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: serviceInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: serviceMuted,
            height: 1.5,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class ServiceInfo extends StatelessWidget {
  const ServiceInfo({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8DD),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: serviceInk, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: serviceMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: serviceInk,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class ServiceReviewCard extends StatelessWidget {
  const ServiceReviewCard({super.key, required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final name = '${review['client_name']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFF3C4),
                  child: Text(
                    serviceInitials(name),
                    style: const TextStyle(color: serviceInk),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: serviceInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serviceDate(review['created_at']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: serviceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: '${review['rating']} de 5 estrelas',
              child: ExcludeSemantics(
                child: Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < (review['rating'] as num)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: serviceYellow,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
            if ('${review['comment']}'.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${review['comment']}',
                style: const TextStyle(color: serviceInk, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfessionalOverview extends StatelessWidget {
  const ProfessionalOverview({
    super.key,
    required this.requests,
    this.counts,
    required this.name,
    required this.open,
    required this.filter,
    required this.profile,
    required this.reviews,
  });
  final List<Map<String, dynamic>> requests;
  final Map<String, dynamic>? counts;
  final String name;
  final void Function(Map<String, dynamic>) open;
  final void Function(String?) filter;
  final VoidCallback profile, reviews;
  @override
  Widget build(BuildContext context) {
    final pending = requests.where((r) => r['status'] == 'pendente').toList();
    final active =
        requests
            .where((r) => ['aceita', 'em_andamento'].contains(r['status']))
            .toList()
          ..sort(
            (a, b) =>
                DateTime.parse(a['scheduled_at'])
                    .compareTo(DateTime.parse(b['scheduled_at'])),
          );
    final completed =
        counts?['concluida'] as int? ??
        requests.where((r) => r['status'] == 'concluida').length;
    final pendingCount = counts?['pendente'] as int? ?? pending.length;
    final activeCount = counts == null
        ? active.length
        : ((counts!['aceita'] as int? ?? 0) +
              (counts!['em_andamento'] as int? ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Olá, ${name.split(' ').first}!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: serviceInk,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Vamos organizar seus atendimentos?',
          style: TextStyle(fontSize: 14, color: serviceMuted),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3C4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.work_outline_rounded,
                size: 32,
                color: serviceInk,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seu trabalho, bem organizado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: serviceInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pendingCount == 0
                          ? 'Sua agenda e suas conversas em um só lugar.'
                          : 'Você tem $pendingCount ${pendingCount == 1 ? 'solicitação aguardando' : 'solicitações aguardando'} resposta.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: serviceInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (_, constraints) {
            final cards = [
              _metric(
                'Aguardando',
                pendingCount,
                Icons.inbox_outlined,
                () => filter('pendente'),
              ),
              _metric(
                'Confirmados',
                activeCount,
                Icons.event_available_outlined,
                () => Navigator.of(context).pushNamed('/pro-agenda'),
              ),
              _metric(
                'Concluídos',
                completed,
                Icons.task_alt,
                () => filter('concluida'),
              ),
            ];
            final columns =
                constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(11) > 15
                ? 2
                : 3;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width:
                          (constraints.maxWidth - 10 * (columns - 1)) / columns,
                      child: card,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        SectionHeading(
          'Próximo atendimento',
          action: TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/pro-agenda'),
            child: const Text('Ver agenda'),
          ),
        ),
        if (active.isNotEmpty)
          ServiceRequestCard(
            request: active.first,
            professional: true,
            onTap: () => open(active.first),
          )
        else
          const ServiceEmpty(
            title: 'Sua agenda está livre',
            description: 'Os serviços confirmados aparecerão aqui.',
            icon: Icons.calendar_today_outlined,
          ),
        SectionHeading(
          'Novas solicitações',
          action: TextButton(
            onPressed: () => filter('pendente'),
            child: const Text('Ver todas'),
          ),
        ),
        if (pending.isEmpty)
          const ServiceEmpty(
            title: 'Tudo em dia',
            description: 'Quando um cliente solicitar um serviço, você poderá responder por aqui.',
          )
        else
          ...pending
              .take(3)
              .map(
                (r) => ServiceRequestCard(
                  request: r,
                  professional: true,
                  onTap: () => open(r),
                ),
              ),
        const SectionHeading('Meu trabalho'),
        Row(
          children: [
            Expanded(
              child: _shortcut(
                'Meu perfil',
                'Especialidade e atendimento',
                Icons.person_outline_rounded,
                profile,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _shortcut(
                'Avaliações',
                'Opiniões dos seus clientes',
                Icons.star_border_rounded,
                reviews,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _metric(String label, int count, IconData icon, VoidCallback tap) =>
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 21, color: serviceYellow),
                const SizedBox(height: 12),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: serviceInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: serviceMuted),
                ),
              ],
            ),
          ),
        ),
      );
  Widget _shortcut(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback tap,
  ) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: tap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: serviceYellow, size: 25),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: serviceInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: serviceMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
