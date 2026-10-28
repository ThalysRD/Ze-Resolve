import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';

import '../../shared/widgets/notifications_modal.dart';

import '../../shared/screens/api_screens.dart';

import '../../shared/widgets/design_data.dart';
import '../../shared/widgets/service_design.dart';

import '../../auth/session/auth_session.dart';

import '../../../core/location/location_service.dart';

import 'professionals_category_screen.dart';

import 'search_screen.dart';

class HomeClientScreen extends StatelessWidget {
  const HomeClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DesignData(
      load: () async => {
        'categories': await designApi.list('/categories'),
        'professionals': await designApi.list(
          '/professionals',
          query: {...await LocationService.searchQuery(), 'limit': '6'},
        ),
      },
      builder: _loaded,
    );
  }

  Widget _loaded(BuildContext context, DesignJson data) {
    const icons = [
      Icons.settings_outlined,
      Icons.water_drop_outlined,
      Icons.format_paint_outlined,
      Icons.content_cut_outlined,
      Icons.desktop_windows_outlined,
      Icons.local_shipping_outlined,
      Icons.inventory_2_outlined,
      Icons.receipt_long_outlined,
    ];

    final categories = designRows(data, 'categories')
        .map(
          (c) => _CategoryItem(
            id: c['id'] as int,
            icon: icons[((c['id'] as int) - 1) % icons.length],
            label: c['name'] as String,
          ),
        )
        .toList();

    final professionals = designRows(data, 'professionals')
        .map(
          (p) => _ProfessionalHomeData(
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Color(0xFFF5B800),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          if (await LocationService.choose(context) &&
                              context.mounted) {
                            DesignData.refresh(context);
                          }
                        },
                        child: Text(
                          LocationService.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2430),
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => showNotificationsModal(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: const NotificationsButton(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ol\u00e1, ${AppSession.user?['name'] ?? ''}!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'O que você precisa hoje?',
                    style: TextStyle(fontSize: 14, color: Color(0xFF7C7C80)),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
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
                              builder: (_) => ProfessionalsCategoryScreen(
                                categoryId: category.id,
                                categoryName: category.label,
                              ),
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
                                  color: const Color(0xFFECECEC),
                                ),
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

                  ServiceSection(
                    title: 'Precisa de atendimento em breve?',
                    icon: Icons.schedule_outlined,
                    children: [
                      const Text(
                        'Veja prestadores com horários livres nas próximas 24 horas. A visita depende da aceitação do profissional.',
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfessionalsCategoryScreen(
                              initialWithin24Hours: true,
                            ),
                          ),
                        ),
                        child: const Text('Próximas 24h'),
                      ),
                    ],
                  ),
                  const Text(
                    'Profissionais em destaque',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (professionals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Nenhum profissional encontrado. Altere a cidade ou amplie o raio de busca.',
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfessionalsCategoryScreen(),
                      ),
                    ),
                    child: const Text('Ver todos os profissionais'),
                  ),
                  ...professionals.map((professional) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveProfessionalScreen(
                                professionalId: professional.id,
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
                              Container(
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
                                          professional.rating.toStringAsFixed(
                                            1,
                                          ),
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
                                    'Valor da visita',
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
  const _CategoryItem({
    required this.id,
    required this.icon,
    required this.label,
  });

  final int id;

  final IconData icon;

  final String label;
}

class _ProfessionalHomeData {
  const _ProfessionalHomeData({
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
