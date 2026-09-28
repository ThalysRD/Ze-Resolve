import 'package:flutter/material.dart';

import '../../client/screens/my_requests_screen.dart';
import '../../client/screens/rate_service_screen.dart';

void showNotificationsModal(BuildContext context, {required bool isClient}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Notificações',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B800),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '3 novas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2430),
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF1B2430),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Notification List
              if (isClient) ...[
                _NotificationItem(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Solicitação confirmada',
                  body:
                      'João Silva aceitou sua solicitação de Instalação elétrica para 15/06 às 14:00.',
                  time: 'Há 10 min',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const MyRequestsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _NotificationItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Nova mensagem',
                  body:
                      'Marcos Lima enviou uma mensagem: "Vou chegar em 15 minutos."',
                  time: 'Há 1 hora',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                _NotificationItem(
                  icon: Icons.star_outline_rounded,
                  iconColor: const Color(0xFFF5B800),
                  title: 'Avaliação pendente',
                  body:
                      'Seu serviço com Pedro Santos foi concluído. Deixe uma avaliação!',
                  time: 'Ontem',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RateServiceScreen()),
                    );
                  },
                ),
              ] else ...[
                _NotificationItem(
                  icon: Icons.handyman_outlined,
                  iconColor: const Color(0xFFF5B800),
                  title: 'Nova solicitação recebida',
                  body:
                      'Thalys Rodrigues solicitou Instalação de Tomada no valor de R\$ 90,00.',
                  time: 'Há 5 min',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                _NotificationItem(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF5B800),
                  title: 'Nova avaliação 5.0 ⭐',
                  body:
                      'Thalys R. deixou um comentário: "Excelente profissional! Chegou pontualmente..."',
                  time: 'Há 2 horas',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                _NotificationItem(
                  icon: Icons.calendar_today_outlined,
                  iconColor: const Color(0xFF22C55E),
                  title: 'Lembrete de agenda',
                  body:
                      'Você tem um atendimento agendado para amanhã às 09:00 com Juliana Medeiros.',
                  time: 'Ontem',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.time,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C7C80),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Color(0xFF6B6B76),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
