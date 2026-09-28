import 'package:flutter/material.dart';

enum NavUserType { client, professional }

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.userType,
    required this.currentIndex,
    this.onTap,
  });

  final NavUserType userType;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    if (onTap != null) {
      onTap!(index);
      return;
    }

    if (userType == NavUserType.client) {
      final routes = [
        '/client-home',
        '/client-search',
        '/client-requests',
        '/client-messages',
        '/client-profile',
      ];
      if (index >= 0 && index < routes.length) {
        if (index == 0) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            routes[index],
            (_) => false,
          );
        } else {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pushReplacementNamed(routes[index]);
          } else {
            Navigator.of(context).pushNamed(routes[index]);
          }
        }
      }
    } else {
      final routes = [
        '/pro-home',
        '/pro-agenda',
        '/pro-requests',
        '/pro-messages',
        '/pro-profile',
      ];
      if (index >= 0 && index < routes.length) {
        if (index == 0) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            routes[index],
            (_) => false,
          );
        } else {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pushReplacementNamed(routes[index]);
          } else {
            Navigator.of(context).pushNamed(routes[index]);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClient = userType == NavUserType.client;

    final items = isClient
        ? const [
            _NavBarItemData(icon: Icons.home_outlined, label: 'Início'),
            _NavBarItemData(icon: Icons.search_rounded, label: 'Buscar'),
            _NavBarItemData(
                icon: Icons.description_outlined, label: 'Solicitações'),
            _NavBarItemData(
                icon: Icons.chat_bubble_outline_rounded, label: 'Mensagens'),
            _NavBarItemData(
                icon: Icons.person_outline_rounded, label: 'Perfil'),
          ]
        : const [
            _NavBarItemData(icon: Icons.home_outlined, label: 'Início'),
            _NavBarItemData(
                icon: Icons.calendar_today_outlined, label: 'Agenda'),
            _NavBarItemData(
                icon: Icons.description_outlined, label: 'Solicitações'),
            _NavBarItemData(
                icon: Icons.chat_bubble_outline_rounded, label: 'Mensagens'),
            _NavBarItemData(
                icon: Icons.person_outline_rounded, label: 'Perfil'),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final active = index == currentIndex;
              return GestureDetector(
                onTap: () => _navigate(context, index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5B800),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 7),
                    Icon(
                      item.icon,
                      size: 22,
                      color: const Color(0xFF1B2430),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: const Color(0xFF1B2430),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItemData {
  const _NavBarItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
