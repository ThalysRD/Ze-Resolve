import 'package:flutter/material.dart';

import '../utils/safe_pop.dart';
import '../widgets/app_bottom_nav_bar.dart';

enum UserProfileType { client, professional }

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({
    super.key,
    this.type = UserProfileType.client,
  });

  final UserProfileType type;

  @override
  Widget build(BuildContext context) {
    if (type == UserProfileType.professional) {
      return const _ProfessionalProfileView();
    }

    return const _ClientProfileView();
  }
}

class _ClientProfileView extends StatelessWidget {
  const _ClientProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => safePop(context, userType: NavUserType.client),
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
                  const Expanded(
                    child: Text(
                      'Perfil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B2430),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFFEFEFEF),
                child: const Icon(Icons.person, size: 52, color: Color(0xFF1B2430)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cliente',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2430),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'cliente@email.com',
                style: TextStyle(fontSize: 13, color: Color(0xFF7C7C80)),
              ),
              const SizedBox(height: 28),
              const _ProfileRow(
                  label: 'Meus dados', icon: Icons.person_outline),
              const _ProfileRow(
                  label: 'Endereços', icon: Icons.location_on_outlined),
              const _ProfileRow(
                  label: 'Serviços favoritos', icon: Icons.favorite_border),
              const _ProfileRow(label: 'Ajuda', icon: Icons.help_outline),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B800),
                    foregroundColor: const Color(0xFF1B2430),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Editar perfil',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        userType: NavUserType.client,
        currentIndex: 4,
      ),
    );
  }
}

class _ProfessionalProfileView extends StatelessWidget {
  const _ProfessionalProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        safePop(context, userType: NavUserType.professional),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFFEFEFEF),
                          child: const Icon(Icons.person,
                              size: 42, color: Color(0xFF1B2430)),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'João Silva',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B2430),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Eletricista · Natal, RN',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7C7C80),
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.star_outline_rounded,
                                      color: Color(0xFFF5B800), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '4.9 (142 avaliações)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF7C7C80),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFECECEC)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sobre mim',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B2430),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Atuo em instalações elétricas, manutenções e pequenos reparos com foco em qualidade e segurança.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7C7C80),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF5B800),
                          foregroundColor: const Color(0xFF1B2430),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Editar perfil',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        userType: NavUserType.professional,
        currentIndex: 4,
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1B2430)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1B2430),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xFF7C7C80),
          ),
        ],
      ),
    );
  }
}
