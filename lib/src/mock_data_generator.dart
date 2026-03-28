import 'dart:math';

import 'mock_registry.dart';

// ---------------------------------------------------------------------------
// MockDataGenerator
// ---------------------------------------------------------------------------

/// A utility class for auto-generating realistic mock payloads.
///
/// [MockDataGenerator] provides:
/// - Type-aware value generation from a JSON schema description.
/// - Fake-data helpers (names, emails, UUIDs, dates …).
/// - `fromJson` helper to wrap an existing JSON map as a [MockResponse].
///
/// ### Example — generate from schema
/// ```dart
/// final schema = {
///   'id':       'uuid',
///   'username': 'name',
///   'email':    'email',
///   'age':      'int',
///   'score':    'double',
///   'active':   'bool',
///   'joined':   'date',
/// };
///
/// final payload = MockDataGenerator.fromSchema(schema);
/// // {id: 'a1b2c3…', username: 'Alice Chen', email: 'alice@example.com', …}
/// ```
class MockDataGenerator {
  MockDataGenerator._();

  static final Random _rng = Random();

  // ── High-level helpers ────────────────────────────────────────────────────

  /// Wraps an existing [json] object in a ready-to-use [MockResponse].
  ///
  /// ```dart
  /// final resp = MockDataGenerator.fromJson({'token': 'xyz'});
  /// ```
  static MockResponse fromJson(
    dynamic json, {
    int statusCode = 200,
    Duration delay = Duration.zero,
  }) {
    return MockResponse(
      statusCode: statusCode,
      body: json,
      delay: delay,
    );
  }

  /// Generates a single mock object from a flat [schema] map.
  ///
  /// Supported type strings (case-insensitive):
  /// | Type string     | Generated value            |
  /// |-----------------|----------------------------|
  /// | `"string"`      | Random lorem word          |
  /// | `"int"`         | Random integer 1–100       |
  /// | `"double"`      | Random double 0.0–100.0    |
  /// | `"bool"`        | Random `true`/`false`      |
  /// | `"uuid"`        | UUID v4-style string       |
  /// | `"name"`        | Random full name           |
  /// | `"email"`       | Random email address       |
  /// | `"phone"`       | Random phone number        |
  /// | `"date"`        | ISO-8601 date string       |
  /// | `"datetime"`    | ISO-8601 datetime string   |
  /// | `"url"`         | Random HTTPS URL           |
  /// | `"color"`       | Hex colour string          |
  /// | `"paragraph"`   | Short lorem paragraph      |
  ///
  /// Any unrecognised type is treated as `"string"`.
  ///
  /// ```dart
  /// final user = MockDataGenerator.fromSchema({
  ///   'id':    'uuid',
  ///   'name':  'name',
  ///   'email': 'email',
  ///   'age':   'int',
  /// });
  /// ```
  static Map<String, dynamic> fromSchema(Map<String, String> schema) {
    return schema.map((key, type) => MapEntry(key, _generateValue(type)));
  }

  /// Generates a list of [count] mock objects using [schema].
  ///
  /// ```dart
  /// final users = MockDataGenerator.listFromSchema(
  ///   {'id': 'uuid', 'name': 'name'},
  ///   count: 5,
  /// );
  /// ```
  static List<Map<String, dynamic>> listFromSchema(
    Map<String, String> schema, {
    int count = 5,
  }) {
    return List.generate(count, (_) => fromSchema(schema));
  }

  /// Builds a paginated response envelope suitable for REST list endpoints.
  ///
  /// ```dart
  /// final page = MockDataGenerator.paginatedList(
  ///   schema: {'id': 'uuid', 'title': 'string'},
  ///   page: 1,
  ///   perPage: 10,
  ///   total: 47,
  /// );
  /// ```
  static Map<String, dynamic> paginatedList({
    required Map<String, String> schema,
    int page = 1,
    int perPage = 10,
    int total = 100,
  }) {
    final totalPages = (total / perPage).ceil();
    return {
      'data': listFromSchema(schema, count: perPage),
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': total,
        'total_pages': totalPages,
        'has_next': page < totalPages,
        'has_prev': page > 1,
      },
    };
  }

  // ── Primitive generators ──────────────────────────────────────────────────

  /// Generates a random UUID v4-style string.
  static String uuid() {
    const chars = '0123456789abcdef';
    String block(int length) =>
        List.generate(length, (_) => chars[_rng.nextInt(chars.length)]).join();
    return '${block(8)}-${block(4)}-4${block(3)}-${block(4)}-${block(12)}';
  }

  /// Generates a random integer between [min] (inclusive) and [max] (inclusive).
  static int randomInt({int min = 1, int max = 100}) =>
      min + _rng.nextInt(max - min + 1);

  /// Generates a random double between [min] and [max], rounded to 2 decimals.
  static double randomDouble({double min = 0.0, double max = 100.0}) {
    final raw = min + _rng.nextDouble() * (max - min);
    return double.parse(raw.toStringAsFixed(2));
  }

  /// Generates a random boolean.
  static bool randomBool() => _rng.nextBool();

  /// Returns a random element from [items].
  static T pickOne<T>(List<T> items) => items[_rng.nextInt(items.length)];

  /// Returns a random full name.
  static String name() {
    const firstNames = [
      'Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace', 'Henry',
      'Iris', 'James', 'Kara', 'Leo', 'Mia', 'Noah', 'Olivia', 'Pete',
    ];
    const lastNames = [
      'Anderson', 'Baker', 'Chen', 'Davis', 'Evans', 'Foster', 'Garcia',
      'Harris', 'Ibrahim', 'Johnson', 'Kim', 'Lopez', 'Miller', 'Nguyen',
    ];
    return '${pickOne(firstNames)} ${pickOne(lastNames)}';
  }

  /// Returns a random-looking email address derived from a random [name].
  static String email() {
    final parts = name().toLowerCase().split(' ');
    const domains = [
      'example.com', 'mail.io', 'test.dev', 'mockapi.net', 'fakemail.org',
    ];
    return '${parts[0]}.${parts[1]}@${pickOne(domains)}';
  }

  /// Returns a random phone number string.
  static String phone() {
    final area = 100 + _rng.nextInt(900);
    final prefix = 100 + _rng.nextInt(900);
    final line = 1000 + _rng.nextInt(9000);
    return '+1-$area-$prefix-$line';
  }

  /// Returns a random ISO-8601 date string within the last 5 years.
  static String date() {
    final now = DateTime.now();
    final offset = Duration(days: _rng.nextInt(365 * 5));
    return now.subtract(offset).toIso8601String().split('T').first;
  }

  /// Returns a random ISO-8601 datetime string within the last 5 years.
  static String datetime() {
    final now = DateTime.now();
    final offset = Duration(
      days: _rng.nextInt(365 * 5),
      hours: _rng.nextInt(24),
      minutes: _rng.nextInt(60),
    );
    return now.subtract(offset).toIso8601String();
  }

  /// Returns a random HTTPS URL.
  static String url() {
    const paths = [
      'api/v1/resource',
      'images/photo',
      'assets/file',
      'docs/page',
    ];
    const hosts = [
      'example.com',
      'mockserver.io',
      'fakeapi.dev',
      'testhost.net',
    ];
    return 'https://${pickOne(hosts)}/${pickOne(paths)}/${randomInt(max: 999)}';
  }

  /// Returns a random hex colour string, e.g. `"#A3F2BC"`.
  static String hexColor() {
    final r = _rng.nextInt(256);
    final g = _rng.nextInt(256);
    final b = _rng.nextInt(256);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  /// Returns a short lorem-ipsum-style paragraph (3–6 sentences).
  static String paragraph() {
    const sentences = [
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      'Pellentesque habitant morbi tristique senectus et netus.',
      'Cras commodo cursus magna vel scelerisque nisl consectetur.',
      'Donec sed odio dui, vitae aliquet leo venenatis.',
      'Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum.',
      'Maecenas sed diam eget risus varius blandit sit amet.',
      'Nulla facilisi cras fermentum odio eu feugiat pretium.',
    ];
    final count = 3 + _rng.nextInt(4);
    final shuffled = List<String>.from(sentences)..shuffle(_rng);
    return shuffled.take(count).join(' ');
  }

  // ── Internal dispatcher ───────────────────────────────────────────────────

  static dynamic _generateValue(String type) {
    switch (type.toLowerCase().trim()) {
      case 'string':
        return _randomWord();
      case 'int':
      case 'integer':
      case 'number':
        return randomInt();
      case 'double':
      case 'float':
        return randomDouble();
      case 'bool':
      case 'boolean':
        return randomBool();
      case 'uuid':
      case 'id':
        return uuid();
      case 'name':
        return name();
      case 'email':
        return email();
      case 'phone':
        return phone();
      case 'date':
        return date();
      case 'datetime':
        return datetime();
      case 'url':
      case 'uri':
        return url();
      case 'color':
      case 'colour':
        return hexColor();
      case 'paragraph':
      case 'text':
      case 'description':
        return paragraph();
      default:
        return _randomWord();
    }
  }

  static String _randomWord() {
    const words = [
      'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'theta', 'iota',
      'kappa', 'lambda', 'omega', 'sigma', 'upsilon', 'phi', 'chi', 'psi',
    ];
    return pickOne(words);
  }
}
