import 'package:flutter/material.dart';

import '../../session/auth_session.dart';
import '../../../client/screens/home_client_screen.dart';
import '../../../professional/screens/home_professional_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String selectedProfile = 'cliente';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Yellow wrench circle logo
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5B800),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    size: 36,
                    color: Color(0xFF1B2430),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Zé Resolve',
                  style: TextStyle(
                    color: Color(0xFF1B2430),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Precisou? Chama o Zé.',
                  style: TextStyle(
                    color: Color(0xFF7C7C80),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Escolha seu perfil',
                style: TextStyle(
                  color: Color(0xFF1B2430),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Para continuar, selecione como você vai usar o app.',
                style: TextStyle(
                  color: Color(0xFF7C7C80),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Contratar serviços
              GestureDetector(
                onTap: () => setState(() => selectedProfile = 'cliente'),
                child: _ProfileOptionCard(
                  title: 'Quero contratar serviços',
                  subtitle:
                      'Encontre profissionais qualificados para resolver seus problemas diários.',
                  icon: Icons.person_search_outlined,
                  selected: selectedProfile == 'cliente',
                ),
              ),
              const SizedBox(height: 14),

              // Option 2: Oferecer serviços
              GestureDetector(
                onTap: () => setState(() => selectedProfile = 'profissional'),
                child: _ProfileOptionCard(
                  title: 'Quero oferecer serviços',
                  subtitle:
                      'Cadastre sua especialidade e encontre clientes em sua região.',
                  icon: Icons.business_center_outlined,
                  selected: selectedProfile == 'profissional',
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    AppSession.login(selectedProfile);

                    if (selectedProfile == 'cliente') {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const HomeClientScreen(),
                        ),
                        (_) => false,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const HomeProfessionalScreen(),
                        ),
                        (_) => false,
                      );
                    }
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
                    'Continuar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOptionCard extends StatelessWidget {
  const _ProfileOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? const Color(0xFFF5B800)
              : const Color(0xFFE0E0E0),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: selected
                  ? const Color(0xFFD97706)
                  : const Color(0xFF7C7C80),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1B2430),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7C7C80),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? const Color(0xFFF5B800) : Colors.transparent,
              border: Border.all(
                color: selected
                    ? const Color(0xFFF5B800)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
