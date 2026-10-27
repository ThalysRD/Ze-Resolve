import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';
import '../../shared/screens/api_screens.dart';
import '../../shared/widgets/design_data.dart';
import '../../../core/location/location_service.dart';

class ProfessionalsCategoryScreen extends StatefulWidget {
  const ProfessionalsCategoryScreen({
    super.key,
    this.categoryId,
    this.categoryName = 'Profissionais',
    this.q = '',
    this.initialWithin24Hours = false,
  });
  final bool initialWithin24Hours;
  final int? categoryId;
  final String categoryName, q;

  @override
  State<ProfessionalsCategoryScreen> createState() =>
      _ProfessionalsCategoryScreenState();
}

class _ProfessionalsCategoryScreenState
    extends State<ProfessionalsCategoryScreen> {
  bool _onlyAvailable = false;
  late bool _within24Hours;
  bool _bestRated = false;

  @override
  void initState() {
    super.initState();
    _within24Hours = widget.initialWithin24Hours;
  }

  @override
  Widget build(BuildContext context) => DesignData(
    load: () async => {
      'professionals': await designApi.all(
        '/professionals',
        query: {
          ...(await LocationService.searchQuery()),
          if (widget.categoryId != null) 'category_id': '${widget.categoryId}',
          if (widget.q.isNotEmpty) 'q': widget.q,
          if (_onlyAvailable) 'available': 'true',
          if (_within24Hours) 'available_within_hours': '24',
          'sort': _bestRated ? 'rating' : 'distance',
        },
      ),
    },
    builder: _loaded,
  );
  void _filter(BuildContext context, String filter) {
    switch (filter) {
      case 'Todos':
        _onlyAvailable = _within24Hours = _bestRated = false;
      case 'Disponíveis':
        _onlyAvailable = !_onlyAvailable;
      case 'Próximas 24h':
        _within24Hours = !_within24Hours;
      case 'Mais bem avaliados':
        _bestRated = !_bestRated;
    }
    DesignData.refresh(context);
  }

  Widget _loaded(BuildContext context, DesignJson data) {
    final professionals = designRows(data, 'professionals')
        .map(
          (p) => _ProfessionalItem(
            id: p['id'] as int,
            name: p['name'] as String,
            specialty: p['category_name'] as String,
            rating: (p['rating'] as num).toDouble(),
            reviews: p['review_count'] as int,
            price:
                '${designPrice(p['visit_fee_cents'])}${p['distance_km'] == null ? '' : ' · ${p['distance_km']} km'}',
            initials: designInitials(p['name'] as String),
          ),
        )
        .toList();
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.categoryName,
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
                    selected: !_onlyAvailable && !_within24Hours && !_bestRated,
                    onTap: () => _filter(context, 'Todos'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Disponíveis',
                    selected: _onlyAvailable,
                    onTap: () => _filter(context, 'Disponíveis'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Próximas 24h',
                    selected: _within24Hours,
                    onTap: () => _filter(context, 'Próximas 24h'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Mais bem avaliados',
                    selected: _bestRated,
                    onTap: () => _filter(context, 'Mais bem avaliados'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Professional Cards List
            Expanded(
              child: professionals.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum profissional encontrado para esses filtros. Remova o filtro de 24 horas, amplie o raio ou escolha outra cidade.',
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: professionals.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = professionals[index];
                        return _ProfessionalCard(
                          professional: item,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LiveProfessionalScreen(
                                  professionalId: item.id,
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
            color: selected ? const Color(0xFFF5B800) : const Color(0xFFE0E0E0),
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
  const _ProfessionalCard({required this.professional, required this.onTap});

  final _ProfessionalItem professional;
  final VoidCallback onTap;

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
            Container(
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          professional.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2430),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF7C7C80),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Badge + Star + Rating + Reviews
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                          text: 'Visita: ',
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
    required this.initials,
  });

  final int id;
  final String name;
  final String specialty;
  final double rating;
  final int reviews;
  final String price;
  final String initials;
}
