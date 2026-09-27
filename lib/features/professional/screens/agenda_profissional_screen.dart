import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';

class AgendaProfissionalScreen extends StatelessWidget {
  const AgendaProfissionalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final dates = [10, 11, 12, 13, 14, 15, 16];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minha Agenda',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Controle seus horários e chamados',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7C7C80),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Month selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Junho 2024',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.chevron_left_rounded,
                              size: 22, color: Color(0xFF1B2430)),
                          SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded,
                              size: 22, color: Color(0xFF1B2430)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Days row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(days.length, (index) {
                      final isSelected = index == 5; // Sáb 15
                      return Column(
                        children: [
                          Text(
                            days[index],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C7C80),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF5B800)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFF5B800)
                                    : const Color(0xFFECECEC),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${dates[index]}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xFF1B2430)
                                      : const Color(0xFF1B2430),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1B2430),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Agenda de hoje header
                  const Text(
                    'Agenda de Hoje',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Agenda item 1
                  const _AgendaItemCard(
                    time: '14:00',
                    duration: '60 min',
                    clientName: 'Thalys Rodrigues',
                    serviceDetails: 'Instalação de Tomada · Lagoa Nova',
                  ),
                  const SizedBox(height: 12),

                  // Agenda item 2
                  const _AgendaItemCard(
                    time: '16:30',
                    duration: '90 min',
                    clientName: 'Juliana Medeiros',
                    serviceDetails: 'Revisão de fiação · Capim Macio',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        userType: NavUserType.professional,
        currentIndex: 1,
        onTap: (index) {
          if (index == 1) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}

class _AgendaItemCard extends StatelessWidget {
  const _AgendaItemCard({
    required this.time,
    required this.duration,
    required this.clientName,
    required this.serviceDetails,
  });

  final String time;
  final String duration;
  final String clientName;
  final String serviceDetails;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2430),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              duration,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7C7C80),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2430),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  serviceDetails,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7C7C80),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
