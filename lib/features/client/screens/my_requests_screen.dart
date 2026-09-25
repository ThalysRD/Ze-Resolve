import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';
import 'request_details_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String _selectedFilter = 'Todos';

  final List<_RequestItemData> _requests = const [
    _RequestItemData(
      id: '1',
      professionalName: 'João Silva',
      serviceName: 'Instalação elétrica',
      dateTime: '15/06/2024 às 14:00',
      status: 'Em andamento',
      imageUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
      initials: 'JS',
    ),
    _RequestItemData(
      id: '2',
      professionalName: 'Marcos Lima',
      serviceName: 'Manutenção de pia',
      dateTime: '10/06/2024 às 09:00',
      status: 'Aguardando confirmação',
      imageUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
      initials: 'ML',
    ),
    _RequestItemData(
      id: '3',
      professionalName: 'Pedro Santos',
      serviceName: 'Instalação de lustre',
      dateTime: '02/06/2024 às 16:00',
      status: 'Concluído',
      imageUrl:
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&auto=format&fit=crop&q=80',
      initials: 'PS',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _requests.where((req) {
      if (_selectedFilter == 'Todos') return true;
      if (_selectedFilter == 'Em andamento') {
        return req.status == 'Em andamento' ||
            req.status == 'Aguardando confirmação';
      }
      if (_selectedFilter == 'Concluídos') return req.status == 'Concluído';
      return true;
    }).toList();

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
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 24,
                        color: Color(0xFF1B2430),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minhas Solicitações',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Histórico e andamento de chamados',
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
                    label: 'Todos',
                    selected: _selectedFilter == 'Todos',
                    onTap: () => setState(() => _selectedFilter = 'Todos'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Em andamento',
                    selected: _selectedFilter == 'Em andamento',
                    onTap: () =>
                        setState(() => _selectedFilter = 'Em andamento'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Concluídos',
                    selected: _selectedFilter == 'Concluídos',
                    onTap: () =>
                        setState(() => _selectedFilter = 'Concluídos'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Requests List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredRequests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filteredRequests[index];
                  return _RequestCard(
                    data: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RequestDetailsScreen(
                            status: item.status,
                            canCancel: item.status != 'Concluído',
                          ),
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
      bottomNavigationBar: const AppBottomNavBar(
        userType: NavUserType.client,
        currentIndex: 2,
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.data, required this.onTap});

  final _RequestItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color statusBg;
    Color statusTextColor;

    if (data.status == 'Em andamento') {
      statusBg = const Color(0xFFFFF8E1);
      statusTextColor = const Color(0xFFD97706);
    } else if (data.status == 'Concluído') {
      statusBg = const Color(0xFFDCFCE7);
      statusTextColor = const Color(0xFF16A34A);
    } else {
      statusBg = const Color(0xFFF3F4F6);
      statusTextColor = const Color(0xFF6B7280);
    }

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    data.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEDEDED),
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
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.professionalName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.serviceName,
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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusTextColor,
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
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF1B2430),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestItemData {
  const _RequestItemData({
    required this.id,
    required this.professionalName,
    required this.serviceName,
    required this.dateTime,
    required this.status,
    required this.imageUrl,
    required this.initials,
  });

  final String id;
  final String professionalName;
  final String serviceName;
  final String dateTime;
  final String status;
  final String imageUrl;
  final String initials;
}
