import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Open-Meteo 
class WeatherService {
  static const _geoHost = 'geocoding-api.open-meteo.com';
  static const _forecastHost = 'api.open-meteo.com';

  /// Поиск городов 
  Future<List<City>> searchCities(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final uri = Uri.https(_geoHost, '/v1/search', {
      'name': q,
      'count': '15',
      'language': 'ru',
      'format': 'json',
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Ошибка поиска: ${res.statusCode}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? [];
    return results
        .map((e) => City.fromGeoJson(e as Map<String, dynamic>))
        .toList();
  }

  /// погода + прогноз на 7 дней 
  Future<WeatherData> getWeather(City city) async {
    final uri = Uri.https(_forecastHost, '/v1/forecast', {
      'latitude': city.lat.toString(),
      'longitude': city.lon.toString(),
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'timezone': 'auto',
      'forecast_days': '7',
      'wind_speed_unit': 'ms',
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки погоды: ${res.statusCode}');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final c = j['current'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;

    final current = CurrentWeather(
      temp: (c['temperature_2m'] as num).toDouble(),
      feelsLike: (c['apparent_temperature'] as num).toDouble(),
      humidity: (c['relative_humidity_2m'] as num).toInt(),
      windSpeed: (c['wind_speed_10m'] as num).toDouble(),
      code: (c['weather_code'] as num).toInt(),
      isDay: (c['is_day'] as num) == 1,
    );

    final dates = d['time'] as List;
    final daily = <DailyForecast>[
      for (var i = 0; i < dates.length; i++)
        DailyForecast(
          date: DateTime.parse(dates[i] as String),
          tMax: ((d['temperature_2m_max'] as List)[i] as num).toDouble(),
          tMin: ((d['temperature_2m_min'] as List)[i] as num).toDouble(),
          code: ((d['weather_code'] as List)[i] as num).toInt(),
        ),
    ];

    return WeatherData(current: current, daily: daily);
  }
}