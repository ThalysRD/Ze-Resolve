import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../errors/user_message.dart';

abstract interface class LocationProvider {
  Future<bool> isEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> locate(LocationSettings settings);
}

class DeviceLocationProvider implements LocationProvider {
  @override
  Future<bool> isEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<Position> locate(LocationSettings settings) =>
      Geolocator.getCurrentPosition(locationSettings: settings);
}

class LocationFailure implements UserFacingException {
  const LocationFailure(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}

class LocationService {
  static LocationProvider provider = DeviceLocationProvider();
  static DateTime Function() now = DateTime.now;
  static Position? position;
  static String city = '';
  static double radiusKm = 25;
  static Position? get freshPosition {
    if (position != null && !_recent(position!, const Duration(minutes: 5))) {
      return null;
    }
    return position;
  }

  static bool _recent(Position p, Duration maxAge) {
    final age = now().toUtc().difference(p.timestamp.toUtc());
    return age <= maxAge && age >= const Duration(minutes: -1);
  }

  static String get label => freshPosition != null
      ? 'Perto de você · até ${radiusKm.round()} km'
      : city.isEmpty
      ? position == null
            ? 'Escolher localização'
            : 'Atualizar localização'
      : city;
  static Map<String, String> get query => {
    if (freshPosition != null) ...{
      'latitude': '${position!.latitude}',
      'longitude': '${position!.longitude}',
      'radius_km': '$radiusKm',
    } else if (city.isNotEmpty)
      'city': city,
  };
  static Future<Map<String, String>> searchQuery() async {
    if (position != null && freshPosition == null) {
      position = await current();
    }
    return query;
  }

  static Future<Position> current() async {
    try {
      if (!await provider.isEnabled()) {
        throw const LocationFailure(
          'Ative a localização do celular e tente novamente.',
        );
      }
      var permission = await provider.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await provider.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(
          'Permita a localização nas configurações do aplicativo ou busque por cidade.',
        );
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const LocationFailure(
          'Localização não autorizada. Você pode buscar por cidade.',
        );
      }
      final result = await provider
          .locate(
            const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20),
            ),
          )
          .timeout(const Duration(seconds: 25));
      if (!result.latitude.isFinite ||
          !result.longitude.isFinite ||
          result.latitude.abs() > 90 ||
          result.longitude.abs() > 180 ||
          !result.accuracy.isFinite ||
          result.accuracy < 0 ||
          result.accuracy > 100 ||
          !_recent(result, const Duration(minutes: 2))) {
        throw const LocationFailure(
          'A localização está imprecisa. Tente novamente em uma área aberta ou busque por cidade.',
        );
      }
      return result;
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(
        'Não foi possível localizar a tempo. Tente novamente ou busque por cidade.',
      );
    } catch (_) {
      throw const LocationFailure(
        'Não foi possível obter sua localização. Tente novamente ou busque por cidade.',
      );
    }
  }

  static Future<bool> choose(BuildContext context) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _LocationSheet(),
      ) ??
      false;
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();
  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _city = TextEditingController(text: LocationService.city);
  double _radius = LocationService.radiusKm;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final position = await LocationService.current();
      if (!mounted) return;
      LocationService.position = position;
      LocationService.city = '';
      LocationService.radiusKm = _radius;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Onde você precisa de atendimento?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Use sua localização para ordenar por proximidade. A distância é aproximada, em linha reta.',
          ),
          Text('Raio de busca: ${_radius.round()} km'),
          Slider(
            value: _radius,
            min: 5,
            max: 100,
            divisions: 19,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _radius = v;
                  }),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _locate,
            icon: const Icon(Icons.my_location),
            label: const Text('Usar minha localização'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              labelText: 'Ou informe sua cidade',
              hintText: 'Ex.: Natal',
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    if (_city.text.trim().length < 2) {
                      setState(() {
                        _error = 'Informe o nome da cidade.';
                      });
                      return;
                    }
                    LocationService.city = _city.text.trim();
                    LocationService.position = null;
                    Navigator.pop(context, true);
                  },
            child: const Text('Buscar por cidade'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    LocationService.city = '';
                    LocationService.position = null;
                    Navigator.pop(context, true);
                  },
            child: const Text('Ver todos os profissionais'),
          ),
        ],
      ),
    ),
  );
}
