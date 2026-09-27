import 'package:flutter/material.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';

class AvaliacoesRecebidasScreen extends StatelessWidget {
  const AvaliacoesRecebidasScreen({super.key});

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
                        'Avaliações',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Feedback dos seus clientes',
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
                  // Reputation Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '4.9',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2430),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: const [
                                Icon(
                                  Icons.star_outline_rounded,
                                  color: Color(0xFFF5B800),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '(142 avaliações)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF7C7C80),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Excelente reputação',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B2430),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '98% dos clientes recomendam seus serviços na região de Natal.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: Color(0xFF7C7C80),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Review 1
                  const _ReviewCard(
                    initials: 'TC',
                    name: 'Thalys R.',
                    subtitle: 'Há 2 dias · Instalação Elétrica',
                    rating: '5.0',
                    text:
                        'Excelente profissional! Chegou pontualmente no horário combinado, resolveu tudo com muita segurança e presteza. Recomendo!',
                  ),
                  const SizedBox(height: 12),

                  // Review 2
                  const _ReviewCard(
                    initials: 'AL',
                    name: 'Ana Lúcia',
                    subtitle: 'Há 1 semana · Reparo de Chuveiro',
                    rating: '4.8',
                    text:
                        'Muito educado e prestativo. Resolveu o curto circuito rapidamente e deixou o local limpo.',
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
        currentIndex: 4,
        onTap: (index) {
          if (index == 4) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.text,
  });

  final String initials;
  final String name;
  final String subtitle;
  final String rating;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7C7C80),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                rating,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2430),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.star_outline_rounded,
                color: Color(0xFFF5B800),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF6B6B76),
            ),
          ),
        ],
      ),
    );
  }
}
