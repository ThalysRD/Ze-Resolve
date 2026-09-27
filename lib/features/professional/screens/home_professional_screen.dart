import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';
import '../../shared/widgets/notifications_modal.dart';
import 'detalhes_solicitacao_profissional_screen.dart';
import 'solicitacoes_recebidas_screen.dart';

class HomeProfessionalScreen extends StatelessWidget {
  const HomeProfessionalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 12),
                  // Location and Bell Notification Header
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Color(0xFFF5B800),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Natal, RN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            showNotificationsModal(context, isClient: false),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 20,
                            color: Color(0xFF1B2430),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Greeting Title
                  const Text(
                    'Olá, João! 👋',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Seu painel de serviços de hoje',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7C7C80),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Recebidas',
                          value: '12',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Concluídos',
                          value: '48',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Nota Geral',
                          value: '4.9',
                          showStar: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Novas Solicitações Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Novas solicitações',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SolicitacoesRecebidasScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Ver todas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF5B800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Request Card 1
                  _RequestCardHome(
                    initials: 'TC',
                    name: 'Thalys Rodrigues',
                    service: 'Instalação de Tomada',
                    dateLocation: 'Hoje às 14:00 · Lagoa Nova',
                    price: 'R\$ 90,00',
                    badgeLabel: 'NOVA',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const DetalhesSolicitacaoProfissionalScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Request Card 2
                  _RequestCardHome(
                    initials: 'MS',
                    name: 'Maria Silva',
                    service: 'Reparo de Chuveiro Elétrico',
                    dateLocation: 'Amanhã às 09:00 · Ponta Negra',
                    price: 'R\$ 120,00',
                    badgeLabel: 'NOVA',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const DetalhesSolicitacaoProfissionalScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        userType: NavUserType.professional,
        currentIndex: 0,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    this.showStar = false,
  });

  final String label;
  final String value;
  final bool showStar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7C7C80),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2430),
                ),
              ),
              if (showStar) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.star_outline_rounded,
                  size: 18,
                  color: Color(0xFFF5B800),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCardHome extends StatelessWidget {
  const _RequestCardHome({
    required this.initials,
    required this.name,
    required this.service,
    required this.dateLocation,
    required this.price,
    required this.badgeLabel,
    required this.onTap,
  });

  final String initials;
  final String name;
  final String service;
  final String dateLocation;
  final String price;
  final String badgeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2430),
                      ),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7C7C80),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateLocation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7C7C80),
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2430),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
