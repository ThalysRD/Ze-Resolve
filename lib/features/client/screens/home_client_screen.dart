import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';
import '../../shared/widgets/notifications_modal.dart';
import 'professional_profile_screen.dart';
import 'professionals_category_screen.dart';
import 'search_screen.dart';

class HomeClientScreen extends StatelessWidget {
  const HomeClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = <_CategoryItem>[
      const _CategoryItem(
        icon: Icons.settings_outlined,
        label: 'Eletricista',
      ),
      const _CategoryItem(
        icon: Icons.water_drop_outlined,
        label: 'Encanador',
      ),
      const _CategoryItem(
        icon: Icons.format_paint_outlined,
        label: 'Pintor',
      ),
      const _CategoryItem(
        icon: Icons.content_cut_outlined,
        label: 'Marceneiro',
      ),
      const _CategoryItem(
        icon: Icons.desktop_windows_outlined,
        label: 'Informática',
      ),
      const _CategoryItem(
        icon: Icons.local_shipping_outlined,
        label: 'Mudanças',
      ),
      const _CategoryItem(
        icon: Icons.inventory_2_outlined,
        label: 'Montagem',
      ),
      const _CategoryItem(
        icon: Icons.receipt_long_outlined,
        label: 'Contabilidade',
      ),
    ];

    final professionals = <_ProfessionalHomeData>[
      const _ProfessionalHomeData(
        name: 'João Silva',
        specialty: 'Eletricista',
        rating: 4.9,
        reviews: 142,
        price: 'R\$ 80,00',
        imageUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
        initials: 'JS',
      ),
      const _ProfessionalHomeData(
        name: 'Marcos Lima',
        specialty: 'Encanador',
        rating: 4.8,
        reviews: 98,
        price: 'R\$ 75,00',
        imageUrl:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
        initials: 'ML',
      ),
    ];

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
                            showNotificationsModal(context, isClient: true),
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
                    'Olá, Cliente!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'O que você precisa hoje?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7C7C80),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar Input
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Color(0xFF9A9AA2),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Buscar serviços ou profissionais',
                              style: TextStyle(
                                color: Color(0xFF9A9AA2),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Categories Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categorias',
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
                              builder: (_) => const SearchScreen(),
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
                  const SizedBox(height: 14),

                  // Categories Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ProfessionalsCategoryScreen(),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFECECEC)),
                              ),
                              child: Icon(
                                category.icon,
                                color: const Color(0xFF1B2430),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1B2430),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Featured Professionals Header
                  const Text(
                    'Profissionais em destaque',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Featured Professionals List
                  ...professionals.map((professional) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfessionalProfileScreen(
                                name: professional.name,
                                specialty: professional.specialty,
                                rating: professional.rating,
                                reviews: professional.reviews,
                                price: professional.price,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFECECEC)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.network(
                                  professional.imageUrl,
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
                                          professional.initials,
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
                                      professional.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1B2430),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      professional.specialty,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7C7C80),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star_outline_rounded,
                                          color: Color(0xFFF5B800),
                                          size: 15,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          professional.rating
                                              .toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1B2430),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${professional.reviews} avaliações)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF7C7C80),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'A partir de',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF7C7C80),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    professional.price,
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
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        userType: NavUserType.client,
        currentIndex: 0,
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _ProfessionalHomeData {
  const _ProfessionalHomeData({
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.imageUrl,
    required this.initials,
  });

  final String name;
  final String specialty;
  final double rating;
  final int reviews;
  final String price;
  final String imageUrl;
  final String initials;
}
