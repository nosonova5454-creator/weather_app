import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'weather_service.dart';

final weatherService = WeatherService();

void main() => runApp(const WeatherApp());

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Погода',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E8BF0),
      ),
      home: const HomeScreen(),
    );
  }
}

// Главный экран 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _prefsKey = 'saved_cities';

  static const _defaultCities = [
    City(name: 'Москва', country: 'Россия', lat: 55.7558, lon: 37.6173),
    City(name: 'Лондон', country: 'Великобритания', lat: 51.5085, lon: -0.1257),
    City(name: 'Нью-Йорк', country: 'США', lat: 40.7143, lon: -74.006),
    City(name: 'Токио', country: 'Япония', lat: 35.6895, lon: 139.6917),
  ];

  List<City> _cities = [];
  bool _loaded = false;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    setState(() {
      _cities = raw == null
          ? List.of(_defaultCities)
          : raw
              .map((s) => City.fromJson(jsonDecode(s) as Map<String, dynamic>))
              .toList();
      _loaded = true;
    });
  }

  Future<void> _saveCities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _cities.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<void> _addCity() async {
    final city = await Navigator.push<City>(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (city == null) return;
    if (_cities.any((c) => c.id == city.id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот город уже в списке')),
      );
      return;
    }
    setState(() => _cities.add(city));
    _saveCities();
  }

  void _removeCity(City city) {
    setState(() => _cities.removeWhere((c) => c.id == city.id));
    _saveCities();
  }

  Future<void> _refresh() async {
    setState(() => _refreshTick++);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Погода'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Найти город',
            onPressed: _addCity,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCity,
        icon: const Icon(Icons.add),
        label: const Text('Добавить город'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _cities.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Список пуст.\nНажмите «Добавить город», чтобы найти любой город мира.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                    itemCount: _cities.length,
                    itemBuilder: (context, i) {
                      final city = _cities[i];
                      return Dismissible(
                        key: ValueKey(city.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _removeCity(city),
                        child: CityCard(
                          key: ValueKey('${city.id}-$_refreshTick'),
                          city: city,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(city: city),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Карточка 

class CityCard extends StatefulWidget {
  final City city;
  final VoidCallback onTap;

  const CityCard({super.key, required this.city, required this.onTap});

  @override
  State<CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<CityCard> {
  late Future<WeatherData> _future;

  @override
  void initState() {
    super.initState();
    _future = weatherService.getWeather(widget.city);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        final colors = data == null
            ? const [Color(0xFF5B8DB8), Color(0xFF9DBCD6)]
            : weatherGradient(data.current.code, data.current.isDay);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.city.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.city.subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              shadows: [Shadow(blurRadius: 3, color: Colors.black26)],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (data != null)
                            Text(
                              weatherDescription(data.current.code),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                shadows: [Shadow(blurRadius: 3, color: Colors.black26)],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (snap.connectionState == ConnectionState.waiting)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else if (snap.hasError)
                      const Icon(Icons.error_outline, color: Colors.white)
                    else if (data != null)
                      Row(
                        children: [
                          Icon(
                            weatherIcon(data.current.code,
                                isDay: data.current.isDay),
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${data.current.temp.round()}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w400,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Поиск 

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<City> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String text) async {
    if (text.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await weatherService.searchCities(text);
      if (!mounted) return;
      setState(() => _results = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось выполнить поиск. Проверьте интернет.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Введите название города',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _results.isEmpty && !_loading && _error == null
                ? const Center(
                    child: Text('Начните вводить название города'),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.location_city),
                        title: Text(c.name),
                        subtitle: Text(c.subtitle),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

//  экран города

class DetailScreen extends StatefulWidget {
  final City city;
  const DetailScreen({super.key, required this.city});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<WeatherData> _future;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    _future = weatherService.getWeather(widget.city);
  }

  void _reload() {
    setState(() => _future = weatherService.getWeather(widget.city));
  }

  String _dayLabel(DateTime d, int index) {
    if (index == 0) return 'Сегодня';
    if (index == 1) return 'Завтра';
    return _weekdays[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        final colors = data == null
            ? const [Color(0xFF5B8DB8), Color(0xFF9DBCD6)]
            : weatherGradient(data.current.code, data.current.isDay);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: snap.connectionState == ConnectionState.waiting
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : snap.hasError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Не удалось загрузить погоду',
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _reload,
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        )
                      : _buildContent(data!),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(WeatherData data) {
    final c = data.current;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(
            widget.city.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Center(
          child: Text(
            widget.city.subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Icon(weatherIcon(c.code, isDay: c.isDay),
              color: Colors.white, size: 80),
        ),
        Center(
          child: Text(
            '${c.temp.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 88,
              fontWeight: FontWeight.w200,
            ),
          ),
        ),
        Center(
          child: Text(
            weatherDescription(c.code),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _InfoTile(
              icon: Icons.thermostat,
              label: 'Ощущается',
              value: '${c.feelsLike.round()}°',
            ),
            _InfoTile(
              icon: Icons.water_drop,
              label: 'Влажность',
              value: '${c.humidity}%',
            ),
            _InfoTile(
              icon: Icons.air,
              label: 'Ветер',
              value: '${c.windSpeed.toStringAsFixed(1)} м/с',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < data.daily.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          _dayLabel(data.daily[i].date, i),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      Icon(weatherIcon(data.daily[i].code),
                          color: Colors.white),
                      const Spacer(),
                      Text(
                        '${data.daily[i].tMin.round()}°',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${data.daily[i].tMax.round()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}