import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart'; // for resolveApiBaseUrl()

/// Model returned from POST /api/farm/analyze
class FarmAdvisoryResult {
  const FarmAdvisoryResult({
    required this.requestId,
    required this.location,
    required this.weather,
    required this.plan,
    required this.processingTimeMs,
    required this.inputSnapshot,
  });

  final String requestId;
  final FarmLocation location;
  final FarmWeather weather;
  final String plan;
  final int processingTimeMs;
  /// Original input fields echoed back (land, crop, soil, water, pincode)
  final Map<String, dynamic> inputSnapshot;

  factory FarmAdvisoryResult.fromJson(Map<String, dynamic> j) {
    return FarmAdvisoryResult(
      requestId: (j['requestId'] ?? '').toString(),
      location: FarmLocation.fromJson(
          (j['location'] as Map<String, dynamic>?) ?? {}),
      weather: FarmWeather.fromJson(
          (j['weather'] as Map<String, dynamic>?) ?? {}),
      plan: (j['plan'] ?? '').toString(),
      processingTimeMs: (j['processingTimeMs'] as num?)?.toInt() ?? 0,
      inputSnapshot: (j['input'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class FarmLocation {
  const FarmLocation({
    required this.pincode,
    required this.postOfficeName,
    required this.district,
    required this.state,
  });
  final String pincode;
  final String postOfficeName;
  final String district;
  final String state;

  factory FarmLocation.fromJson(Map<String, dynamic> j) => FarmLocation(
        pincode: (j['pincode'] ?? '').toString(),
        postOfficeName: (j['postOfficeName'] ?? '').toString(),
        district: (j['district'] ?? '').toString(),
        state: (j['state'] ?? '').toString(),
      );
}

class FarmWeatherCurrent {
  const FarmWeatherCurrent({
    required this.temperature,
    required this.humidity,
    required this.condition,
    required this.windSpeed,
    required this.isFallback,
  });
  final int temperature;
  final int humidity;
  final String condition;
  final double windSpeed;
  final bool isFallback;

  factory FarmWeatherCurrent.fromJson(Map<String, dynamic> j) =>
      FarmWeatherCurrent(
        temperature: (j['temperature'] as num?)?.toInt() ?? 0,
        humidity: (j['humidity'] as num?)?.toInt() ?? 0,
        condition: (j['condition'] ?? 'N/A').toString(),
        windSpeed: (j['windSpeed'] as num?)?.toDouble() ?? 0.0,
        isFallback: (j['isFallback'] as bool?) ?? false,
      );
}

class FarmWeatherDay {
  const FarmWeatherDay({
    required this.date,
    required this.temperature,
    required this.humidity,
    required this.condition,
  });
  final String date;
  final int temperature;
  final int humidity;
  final String condition;

  factory FarmWeatherDay.fromJson(Map<String, dynamic> j) => FarmWeatherDay(
        date: (j['date'] ?? '').toString(),
        temperature: (j['temperature'] as num?)?.toInt() ?? 0,
        humidity: (j['humidity'] as num?)?.toInt() ?? 0,
        condition: (j['condition'] ?? '').toString(),
      );
}

class FarmWeather {
  const FarmWeather({required this.current, required this.forecast});
  final FarmWeatherCurrent current;
  final List<FarmWeatherDay> forecast;

  factory FarmWeather.fromJson(Map<String, dynamic> j) => FarmWeather(
        current: FarmWeatherCurrent.fromJson(
            (j['current'] as Map<String, dynamic>?) ?? {}),
        forecast: ((j['forecast'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(FarmWeatherDay.fromJson)
            .toList(),
      );
}

/// Service that talks to the backend /api/farm endpoints.
class FarmAdvisoryService {
  FarmAdvisoryService({String? baseUrl})
      : _base = baseUrl ?? resolveApiBaseUrl();

  final String _base;
  final _client = http.Client();

  Uri _uri(String path) => Uri.parse('$_base$path');

  Future<FarmAdvisoryResult> analyze({
    required double land,
    required String crop,
    required String soil,
    required String water,
    required String pincode,
  }) async {
    final body = {
      'land': land,
      'crop': crop,
      'soil': soil,
      'water': water,
      'pincode': pincode,
    };

    final res = await _client
        .post(
          _uri('/farm/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    final respBody = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // Inject input snapshot so the result carries it for PDF generation
      respBody['input'] = body;
      return FarmAdvisoryResult.fromJson(respBody);
    }

    final msg = respBody['error']?.toString() ??
        respBody['message']?.toString() ??
        'Request failed (${res.statusCode})';
    throw Exception(msg);
  }

  /// Downloads a PDF report as raw bytes from the backend.
  Future<List<int>> downloadPDF({
    required Map<String, dynamic> input,
    required FarmLocation location,
    required FarmWeather weather,
    required String plan,
  }) async {
    final res = await _client
        .post(
          _uri('/farm/download-pdf'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'input': input,
            'location': {
              'pincode':        location.pincode,
              'postOfficeName': location.postOfficeName,
              'district':       location.district,
              'state':          location.state,
            },
            'weather': {
              'current': {
                'temperature': weather.current.temperature,
                'feelsLike':   0,
                'humidity':    weather.current.humidity,
                'condition':   weather.current.condition,
                'windSpeed':   weather.current.windSpeed,
                'isFallback':  weather.current.isFallback,
              },
              'forecast': weather.forecast.map((d) => {
                'date':        d.date,
                'temperature': d.temperature,
                'humidity':    d.humidity,
                'condition':   d.condition,
              }).toList(),
            },
            'plan': plan,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }

    String msg = 'PDF generation failed (${res.statusCode})';
    try {
      final errBody = jsonDecode(res.body);
      if (errBody is Map && errBody['error'] != null) msg = errBody['error'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  void dispose() => _client.close();
}
