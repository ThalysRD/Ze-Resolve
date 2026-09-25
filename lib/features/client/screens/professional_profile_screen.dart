import 'package:flutter/material.dart';

import 'service_request_screen.dart';

class ProfessionalProfileScreen extends StatelessWidget {
  const ProfessionalProfileScreen({
    super.key,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviews,
    required this.price,
    this.imageUrl,
  });

  final String name;
  final String specialty;
  final double rating;
  final int reviews;
  final String price;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = imageUrl ??
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80';

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
                        'Perfil do Profissional',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Detalhes e especialidades',
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    // Profile avatar photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(
                        avatarUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDEDED),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 56,
                              color: Color(0xFF1B2430),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Name
                    Text(
                      name,
                      style: const TextStyle(
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
                        'Eletricista Autônomo',
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
                      children: [
                        const Icon(
                          Icons.star_outline_rounded,
                          color: Color(0xFFF5B800),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2430),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($reviews avaliações)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7C7C80),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Location & Verified Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF7C7C80),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Natal, RN',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C7C80),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Ativo na região',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    const Divider(color: Color(0xFFE8E8E8), height: 1),
                    const SizedBox(height: 20),

                    // Sobre mim
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sobre mim',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sou eletricista profissional com mais de 8 anos de experiência em instalações residenciais e prediais. Prezo pela segurança, rapidez e qualidade no serviço prestado.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF6B6B76),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Serviços em destaque
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Serviços em destaque',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const _ServiceCard(
                      title: 'Instalação elétrica',
                      price: 'R\$ 80,00',
                    ),
                    const SizedBox(height: 10),
                    const _ServiceCard(
                      title: 'Manutenção elétrica',
                      price: 'R\$ 70,00',
                    ),
                    const SizedBox(height: 10),
                    const _ServiceCard(
                      title: 'Troca de fiação',
                      price: 'R\$ 120,00',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ServiceRequestScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5B800),
                      foregroundColor: const Color(0xFF1B2430),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Solicitar serviço',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.title, required this.price});

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
              fontWeight: FontWeight.w500,
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
