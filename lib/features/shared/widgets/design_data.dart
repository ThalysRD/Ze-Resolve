import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/location/location_service.dart';

typedef DesignJson = Map<String, dynamic>;
ApiClient get designApi => ApiClient.instance;
String designPrice(dynamic value) => value == null
    ? 'A definir'
    : 'R\$ ${((value as num) / 100).toStringAsFixed(2).replaceAll('.', ',')}';
String designInitials(String name) => name
    .split(' ')
    .where((s) => s.isNotEmpty)
    .take(2)
    .map((s) => s[0])
    .join()
    .toUpperCase();
List<DesignJson> designRows(DesignJson data, String field) =>
    (data[field] as List).cast<DesignJson>();

class DesignData extends StatefulWidget {
  const DesignData({super.key, required this.load, required this.builder});
  final Future<DesignJson> Function() load;
  final Widget Function(BuildContext, DesignJson) builder;
  @override
  State<DesignData> createState() => _DesignDataState();
  static void refresh(BuildContext context) =>
      context.findAncestorStateOfType<_DesignDataState>()?.refresh();
}

class _DesignDataState extends State<DesignData> {
  late Future<DesignJson> _data;
  @override
  void initState() {
    super.initState();
    _data = widget.load();
  }

  void refresh() => setState(() {
    _data = widget.load();
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<DesignJson>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: Color(0xFFF7F7F7),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFF5B800)),
          ),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 36,
                      color: Color(0xFF1B2430),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userErrorMessage(snapshot.error),
                      textAlign: TextAlign.center,
                    ),
                    if (snapshot.error is LocationFailure)
                      TextButton(
                        onPressed: () async {
                          final changed = await LocationService.choose(context);
                          if (changed && mounted) refresh();
                        },
                        child: const Text('Escolher localização ou cidade'),
                      ),
                    FilledButton(
                      onPressed: refresh,
                      child: const Text('Tentar novamente'),
                    ),
                    if (Navigator.of(context).canPop())
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Voltar'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Builder(
        builder: (context) => widget.builder(context, snapshot.data!),
      );
    },
  );
}
