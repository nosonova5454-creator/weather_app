import 'package:flutter/material.dart';

class City {
  final String name;
  final String country;
  final String? region;
  final double lat;
  final double lon;

  const City({
    required this.name,
    required this.country,
    this.region,
    required this.lat,
    required this.lon,
  });

  String get id => '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

  String get subtitle => [
        if (region != null && region!.isNotEmpty && region != name) region,
        country,
      ].join(', ');

  factory City.fromGeoJson(Map<String, dynamic> j) => City(
        name: j['name'] as String,
        country: (j['country'] ?? '') as String,
        region: j['admin1'] as String?,
        lat: (j['latitude'] as num).toDouble(),
        lon: (j['longitude'] as num).toDouble(),
      );

  factory City.fromJson(Map<String, dynamic> j) => City(
        name: j['name'] as String,
        country: j['country'] as String,
        region: j['region'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'region': region,
        'lat': lat,
        'lon': lon,
      };
}

class CurrentWeather {
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int code;
  final bool isDay;

  CurrentWeather({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.code,
    required this.isDay,
  });
}

class DailyForecast {
  final DateTime date;
  final double tMax;
  final double tMin;
  final int code;

  DailyForecast({
    required this.date,
    required this.tMax,
    required this.tMin,
    required this.code,
  });
}

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> daily;

  WeatherData({required this.current, required this.daily});
}

/// Описание иконка  (Open-Meteo).
String weatherDescription(int code) {
  switch (code) {
    case 0:
      return 'Ясно';
    case 1:
      return 'Преимущественно ясно';
    case 2:
      return 'Переменная облачность';
    case 3:
      return 'Пасмурно';
    case 45:
    case 48:
      return 'Туман';
    case 51:
    case 53:
    case 55:
      return 'Морось';
    case 56:
    case 57:
      return 'Ледяная морось';
    case 61:
      return 'Небольшой дождь';
    case 63:
      return 'Дождь';
    case 65:
      return 'Сильный дождь';
    case 66:
    case 67:
      return 'Ледяной дождь';
    case 71:
      return 'Небольшой снег';
    case 73:
      return 'Снег';
    case 75:
      return 'Сильный снег';
    case 77:
      return 'Снежная крупа';
    case 80:
    case 81:
    case 82:
      return 'Ливень';
    case 85:
    case 86:
      return 'Снегопад';
    case 95:
      return 'Гроза';
    case 96:
    case 99:
      return 'Гроза с градом';
    default:
      return 'Нет данных';
  }
}

IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0 || code == 1) {
    return isDay ? Icons.wb_sunny : Icons.nightlight_round;
  }
  if (code == 2) return isDay ? Icons.wb_cloudy : Icons.cloud;
  if (code == 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain;
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 80 && code <= 82) return Icons.umbrella;
  if (code == 85 || code == 86) return Icons.ac_unit;
  if (code >= 95) return Icons.thunderstorm;
  return Icons.help_outline;
}

List<Color> weatherGradient(int code, bool isDay) {
  if (!isDay) return const [Color(0xFF1B2735), Color(0xFF3A4A66)];
  if (code == 0 || code == 1) {
    return const [Color(0xFF2E8BF0), Color(0xFF6FC3FF)];
  }
  if (code >= 95) return const [Color(0xFF3A3F5C), Color(0xFF6B6F8D)];
  if (code >= 71 && code <= 86) {
    return const [Color(0xFF4A7A9B), Color(0xFF6FA3C0)];
  }
  if (code >= 51) return const [Color(0xFF4F6D8F), Color(0xFF8CA5BF)];
  return const [Color(0xFF5B8DB8), Color(0xFF9DBCD6)];
}