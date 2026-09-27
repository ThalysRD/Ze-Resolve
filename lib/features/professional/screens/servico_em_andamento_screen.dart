import 'package:flutter/material.dart';

class ServicoEmAndamentoScreen extends StatelessWidget {
  const ServicoEmAndamentoScreen({super.key});

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
                        'Serviço Ativo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2430),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Acompanhamento do chamado',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client summary card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFECECEC)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'TC',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B2430),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thalys Rodrigues',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B2430),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Instalação de Tomada · R\$ 90,00',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7C7C80),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress Section Title
                    const Text(
                      'Progresso do Serviço',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B2430),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress Steps
                    const _ProgressStep(
                      title: 'Solicitação aceita',
                      subtitle: 'Confirmado às 10:30',
                      status: _StepStatus.completed,
                    ),
                    const _ProgressStep(
                      title: 'A caminho',
                      subtitle: 'Marcado às 13:45',
                      status: _StepStatus.completed,
                    ),
                    const _ProgressStep(
                      title: 'Em execução',
                      subtitle: 'Iniciado às 14:05 (Andamento)',
                      status: _StepStatus.inProgress,
                    ),
                    const _ProgressStep(
                      title: 'Concluído',
                      subtitle: 'Aguardando finalização',
                      status: _StepStatus.pending,
                      isLast: true,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Serviço concluído com sucesso!'),
                          backgroundColor: Color(0xFF22C55E),
                        ),
                      );
                      Navigator.of(context).pushReplacementNamed('/pro-agenda');
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
                      'Marcar como concluído',
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

enum _StepStatus { completed, inProgress, pending }

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.title,
    required this.subtitle,
    required this.status,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final _StepStatus status;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color lineColor;
    Color subtitleColor;

    if (status == _StepStatus.completed) {
      dotColor = const Color(0xFF22C55E);
      lineColor = const Color(0xFF22C55E);
      subtitleColor = const Color(0xFF7C7C80);
    } else if (status == _StepStatus.inProgress) {
      dotColor = const Color(0xFFF5B800);
      lineColor = const Color(0xFFE5E7EB);
      subtitleColor = const Color(0xFFD97706);
    } else {
      dotColor = Colors.white;
      lineColor = const Color(0xFFE5E7EB);
      subtitleColor = const Color(0xFF7C7C80);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: status == _StepStatus.pending
                      ? const Color(0xFFD1D5DB)
                      : dotColor,
                  width: 2,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: status == _StepStatus.pending
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF1B2430),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: status == _StepStatus.inProgress
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }
}
