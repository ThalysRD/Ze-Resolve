import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';

class MeuPerfilProfissionalScreen extends StatefulWidget {
  const MeuPerfilProfissionalScreen({super.key});

  @override
  State<MeuPerfilProfissionalScreen> createState() =>
      _MeuPerfilProfissionalScreenState();
}

class _MeuPerfilProfissionalScreenState
    extends State<MeuPerfilProfissionalScreen> {
  bool _isAvailable = true;

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
                        'Meu Perfil',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Configurações e especialidades',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Profile avatar photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(
                        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDEDED),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 50,
                              color: Color(0xFF1B2430),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Name
                    const Text(
                      'João Silva',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B2430),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Eletricista Profissional',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.star_outline_rounded,
                          color: Color(0xFFF5B800),
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '4.9',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2430),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '(142 avaliações)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7C7C80),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Availability Switch Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFECECEC)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Disponível para novos chamados',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2430),
                            ),
                          ),
                          Switch.adaptive(
                            value: _isAvailable,
                            activeThumbColor: const Color(0xFFF5B800),
                            onChanged: (value) {
                              setState(() => _isAvailable = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Meus Serviços Title
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Meus Serviços',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Service 1
                    const _ServiceProfileCard(
                      title: 'Instalação de Tomada',
                      price: 'R\$ 80,00',
                    ),
                    const SizedBox(height: 10),

                    // Service 2
                    const _ServiceProfileCard(
                      title: 'Manutenção Elétrica',
                      price: 'R\$ 70,00',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        userType: NavUserType.professional,
        currentIndex: 4,
        onTap: (index) {
          if (index == 4) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}

class _ServiceProfileCard extends StatelessWidget {
  const _ServiceProfileCard({required this.title, required this.price});

  final String title;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2430),
            ),
          ),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                const TextSpan(
                  text: 'A partir de ',
                  style: TextStyle(color: Color(0xFF7C7C80)),
                ),
                TextSpan(
                  text: price,
                  style: const TextStyle(
                    color: Color(0xFF1B2430),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
