import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';
import 'professional_profile_screen.dart';

class ProfessionalsCategoryScreen extends StatefulWidget {
  const ProfessionalsCategoryScreen({super.key});

  @override
  State<ProfessionalsCategoryScreen> createState() =>
      _ProfessionalsCategoryScreenState();
}

class _ProfessionalsCategoryScreenState
    extends State<ProfessionalsCategoryScreen> {
  String _selectedFilter = 'Todos';

  late List<_ProfessionalItem> _professionals;

  @override
  void initState() {
    super.initState();
    _professionals = [
      _ProfessionalItem(
        id: '1',
        name: 'João Silva',
        specialty: 'Eletricista',
        rating: 4.9,
        reviews: 142,
        price: 'R\$ 80,00',
        imageUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
        initials: 'JS',
        isFavorite: true,
      ),
      _ProfessionalItem(
        id: '2',
        name: 'Marcos Lima',
        specialty: 'Eletricista',
        rating: 4.8,
        reviews: 98,
        price: 'R\$ 75,00',
        imageUrl:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
        initials: 'ML',
        isFavorite: false,
      ),
      _ProfessionalItem(
        id: '3',
        name: 'Pedro Santos',
        specialty: 'Eletricista',
        rating: 4.7,
        reviews: 76,
        price: 'R\$ 90,00',
        imageUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&auto=format&fit=crop&q=80',
        initials: 'PS',
        isFavorite: false,
      ),
      _ProfessionalItem(
        id: '4',
        name: 'Renato Alves',
        specialty: 'Eletricista',
        rating: 4.6,
        reviews: 54,
        price: 'R\$ 85,00',
        imageUrl:
            'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&auto=format&fit=crop&q=80',
        initials: 'RA',
        isFavorite: false,
      ),
    ];
  }

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
                        'Eletricistas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Encontre o profissional ideal',
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
                    label: 'Disponíveis',
                    selected: _selectedFilter == 'Disponíveis',
                    onTap: () => setState(() => _selectedFilter = 'Disponíveis'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Mais bem avaliados',
                    selected: _selectedFilter == 'Mais bem avaliados',
                    onTap: () =>
                        setState(() => _selectedFilter = 'Mais bem avaliados'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Professional Cards List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _professionals.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _professionals[index];
                  return _ProfessionalCard(
                    professional: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfessionalProfileScreen(
                            name: item.name,
                            specialty: item.specialty,
                            rating: item.rating,
                            reviews: item.reviews,
                            price: item.price,
                          ),
                        ),
                      );
                    },
                    onFavoriteToggle: () {
                      setState(() {
                        item.isFavorite = !item.isFavorite;
                      });
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
        currentIndex: 1,
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

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({
    required this.professional,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final _ProfessionalItem professional;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.network(
                professional.imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDEDED),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        professional.initials,
                        style: const TextStyle(
                          fontSize: 15,
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
                  // Title + Favorite button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        professional.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Icon(
                          professional.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: professional.isFavorite
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF7C7C80),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Badge + Star + Rating + Reviews
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          professional.specialty,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star_outline_rounded,
                        color: Color(0xFFF5B800),
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        professional.rating.toStringAsFixed(1),
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
                  const SizedBox(height: 8),

                  // Price
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        const TextSpan(
                          text: 'A partir de ',
                          style: TextStyle(color: Color(0xFF7C7C80)),
                        ),
                        TextSpan(
                          text: professional.price,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalItem {
  _ProfessionalItem({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.imageUrl,
    required this.initials,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int reviews;
  final String price;
  final String imageUrl;
  final String initials;
  bool isFavorite;
}
