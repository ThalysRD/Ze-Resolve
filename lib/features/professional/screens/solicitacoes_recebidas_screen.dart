import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';
import 'detalhes_solicitacao_profissional_screen.dart';

class SolicitacoesRecebidasScreen extends StatefulWidget {
  const SolicitacoesRecebidasScreen({super.key});

  @override
  State<SolicitacoesRecebidasScreen> createState() =>
      _SolicitacoesRecebidasScreenState();
}

class _SolicitacoesRecebidasScreenState
    extends State<SolicitacoesRecebidasScreen> {
  String _selectedFilter = 'Novas';

  final List<_ProfessionalRequestData> _requests = const [
    _ProfessionalRequestData(
      initials: 'TC',
      name: 'Thalys Rodrigues',
      service: 'Instalação de Disjuntor',
      dateTime: '15/06/2024 às 14:00',
      price: 'R\$ 90,00',
      badgeLabel: 'NOVA',
    ),
    _ProfessionalRequestData(
      initials: 'ML',
      name: 'Marcos Lima',
      service: 'Curto-circuito na cozinha',
      dateTime: '16/06/2024 às 10:00',
      price: 'R\$ 150,00',
      badgeLabel: 'NOVA',
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
                        'Solicitações Recebidas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lista e acompanhamento de chamados',
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

            // Filter Chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'Novas',
                    selected: _selectedFilter == 'Novas',
                    onTap: () => setState(() => _selectedFilter = 'Novas'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Aceitas',
                    selected: _selectedFilter == 'Aceitas',
                    onTap: () => setState(() => _selectedFilter = 'Aceitas'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Ativas',
                    selected: _selectedFilter == 'Ativas',
                    onTap: () => setState(() => _selectedFilter = 'Ativas'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Requests list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _requests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _requests[index];
                  return _RequestCardItem(
                    data: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const DetalhesSolicitacaoProfissionalScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        userType: NavUserType.professional,
        currentIndex: 2,
        onTap: (index) {
          if (index == 2) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5B800) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFF5B800)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B2430),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCardItem extends StatelessWidget {
  const _RequestCardItem({required this.data, required this.onTap});

  final _ProfessionalRequestData data;
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
                      data.initials,
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
                        data.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.service,
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
                    data.badgeLabel,
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
            const Divider(color: Color(0xFFF0F0F0), height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFF7C7C80),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      data.dateTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C7C80),
                      ),
                    ),
                  ],
                ),
                Text(
                  data.price,
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

class _ProfessionalRequestData {
  const _ProfessionalRequestData({
    required this.initials,
    required this.name,
    required this.service,
    required this.dateTime,
    required this.price,
    required this.badgeLabel,
  });

  final String initials;
  final String name;
  final String service;
  final String dateTime;
  final String price;
  final String badgeLabel;
}
