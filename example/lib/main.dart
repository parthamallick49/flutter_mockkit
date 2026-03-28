/// Example Flutter app demonstrating all `flutter_mockkit` features.
///
/// Run with:  flutter run -d <device>
library flutter_mockkit_example;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_mockkit/flutter_mockkit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bootstrap
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  _setupMocks();
  runApp(const MockKitDemoApp());
}

/// Registers all demo routes and enables MockKit in verbose-logging mode.
void _setupMocks() {
  MockKit.enable();
  MockKit.enableLogging();
  // Add a small global latency so the loading indicators are visible.
  MockKit.setGlobalDelay(const Duration(milliseconds: 200));

  // ── 1. Simple GET ──────────────────────────────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.get,
    path: '/users',
    description: 'Returns a paginated list of users',
    response: MockResponse.ok(
      MockDataGenerator.paginatedList(
        schema: {
          'id': 'uuid',
          'name': 'name',
          'email': 'email',
          'active': 'bool',
        },
        perPage: 5,
        total: 42,
      ),
    ),
  ));

  // ── 2. Dynamic GET – parameterised path ───────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.get,
    path: '/users/:id',
    description: 'Returns a single user by ID',
    responseBuilder: (request) {
      final id = request.pathParameters['id']!;
      return MockResponse.ok({
        'id': id,
        'name': MockDataGenerator.name(),
        'email': MockDataGenerator.email(),
        'joined': MockDataGenerator.date(),
        'bio': MockDataGenerator.paragraph(),
      });
    },
  ));

  // ── 3. POST with body echo ────────────────────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.post,
    path: '/users',
    description: 'Creates a new user',
    responseBuilder: (request) {
      final body = request.bodyAsJson;
      if (body['name'] == null || (body['name'] as String).isEmpty) {
        return MockResponse.badRequest(message: '"name" is required');
      }
      return MockResponse.created({
        'id': MockDataGenerator.uuid(),
        ...body,
        'created_at': MockDataGenerator.datetime(),
      });
    },
  ));

  // ── 4. Simulated delay ────────────────────────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.get,
    path: '/slow-endpoint',
    description: 'Simulates a slow backend (1 s extra latency)',
    response: MockResponse.ok(
      {'data': 'This response was slow on purpose'},
      delay: const Duration(seconds: 1),
    ),
  ));

  // ── 5. Error simulation ───────────────────────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.get,
    path: '/server-error',
    description: 'Simulates a 500 server error',
    response: MockResponse.serverError(
      message: 'Internal server error — this is a mock!',
    ),
  ));

  // ── 6. Network failure ────────────────────────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.get,
    path: '/network-failure',
    description: 'Simulates a complete network failure',
    response: MockResponse.networkFailure(
      message: 'Could not reach server — simulated timeout',
    ),
  ));

  // ── 7. PUT update ──────────────────────────────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.put,
    path: '/users/:id',
    responseBuilder: (request) {
      final id = request.pathParameters['id']!;
      final body = request.bodyAsJson;
      return MockResponse.ok({'id': id, ...body, 'updated': true});
    },
  ));

  // ── 8. DELETE ──────────────────────────────────────────────────────────────
  MockKit.register(MockRoute(
    method: HttpMethod.delete,
    path: '/users/:id',
    responseBuilder: (request) {
      return MockResponse(statusCode: 204, body: null);
    },
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// App widget
// ─────────────────────────────────────────────────────────────────────────────

class MockKitDemoApp extends StatelessWidget {
  const MockKitDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_mockkit Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const DemoHomePage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home page
// ─────────────────────────────────────────────────────────────────────────────

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  // Shared Dio instance with the mock interceptor attached
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..interceptors.add(MockDioInterceptor());

  // Shared http.Client that routes through MockKit
  final http.Client _httpClient = MockHttpClient();

  bool _mockEnabled = true;
  String _output = 'Tap a demo button to see results here.';
  bool _loading = false;

  void _setOutput(String text) => setState(() => _output = text);
  void _startLoading() => setState(() => _loading = true);
  void _stopLoading() => setState(() => _loading = false);

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  // ── Demos ─────────────────────────────────────────────────────────────────

  Future<void> _demoGetUsers() async {
    _startLoading();
    try {
      final response = await _dio.get('/users');
      _setOutput(_prettyJson(response.data));
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoDynamicGet() async {
    _startLoading();
    try {
      final id = MockDataGenerator.randomInt(min: 100, max: 999);
      final response = await _dio.get('/users/$id');
      _setOutput(_prettyJson(response.data));
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoPostUser() async {
    _startLoading();
    try {
      final response = await _dio.post(
        '/users',
        data: {
          'name': MockDataGenerator.name(),
          'email': MockDataGenerator.email(),
        },
      );
      _setOutput(_prettyJson(response.data));
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoPostUserBadRequest() async {
    _startLoading();
    try {
      // Send empty name to trigger 400 from the dynamic builder
      final response = await _dio.post('/users', data: {'name': ''});
      _setOutput(_prettyJson(response.data));
    } on DioException catch (e) {
      _setOutput(
        'DioException (${e.response?.statusCode}): '
        '${_prettyJson(e.response?.data)}',
      );
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoSlowEndpoint() async {
    _startLoading();
    _setOutput('⏳ Waiting for slow endpoint…');
    try {
      final start = DateTime.now();
      final response = await _dio.get('/slow-endpoint');
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      _setOutput(
        '${_prettyJson(response.data)}\n\nElapsed: ${elapsed}ms',
      );
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoServerError() async {
    _startLoading();
    try {
      final response = await _dio.get('/server-error');
      _setOutput(_prettyJson(response.data));
    } on DioException catch (e) {
      _setOutput(
        'Status ${e.response?.statusCode}: '
        '${_prettyJson(e.response?.data)}',
      );
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoNetworkFailure() async {
    _startLoading();
    try {
      await _dio.get('/network-failure');
    } on DioException catch (e) {
      _setOutput('⚡ Network failure intercepted:\n${e.message}');
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoHttpPackage() async {
    _startLoading();
    try {
      final uri = Uri.parse('https://api.example.com/users');
      final response = await _httpClient.get(uri);
      _setOutput(
        'http package — status ${response.statusCode}\n\n'
        '${_prettyJson(jsonDecode(response.body))}',
      );
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _demoGeneratedData() async {
    _startLoading();
    try {
      final products = MockDataGenerator.listFromSchema(
        {
          'id': 'uuid',
          'name': 'string',
          'price': 'double',
          'color': 'color',
          'description': 'paragraph',
          'in_stock': 'bool',
        },
        count: 3,
      );
      _setOutput(_prettyJson({'generated_products': products}));
    } catch (e) {
      _setOutput('Error: $e');
    } finally {
      _stopLoading();
    }
  }

  void _toggleMockMode() {
    setState(() {
      _mockEnabled = !_mockEnabled;
      if (_mockEnabled) {
        MockKit.enable();
      } else {
        MockKit.disable();
      }
      _output =
          _mockEnabled
              ? '✅ Mock mode ENABLED — requests are intercepted.'
              : '🌐 Live mode ENABLED — requests go to the real network.';
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_mockkit Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  _mockEnabled ? 'Mock' : 'Live',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _mockEnabled,
                  onChanged: (_) => _toggleMockMode(),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Left panel: buttons ──────────────────────────────────────────
          SizedBox(
            width: 260,
            child: Material(
              elevation: 2,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                children: [
                  _sectionLabel('HTTP Client (Dio)'),
                  _demoButton('GET /users', _demoGetUsers, Colors.blue),
                  _demoButton(
                    'GET /users/:id (dynamic)',
                    _demoDynamicGet,
                    Colors.indigo,
                  ),
                  _demoButton(
                    'POST /users (valid)',
                    _demoPostUser,
                    Colors.green,
                  ),
                  _demoButton(
                    'POST /users (bad req)',
                    _demoPostUserBadRequest,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel('Network Conditions'),
                  _demoButton(
                    'GET /slow-endpoint',
                    _demoSlowEndpoint,
                    Colors.amber.shade800,
                  ),
                  _demoButton(
                    'GET /server-error (500)',
                    _demoServerError,
                    Colors.red.shade700,
                  ),
                  _demoButton(
                    'GET /network-failure',
                    _demoNetworkFailure,
                    Colors.red.shade900,
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel('http package'),
                  _demoButton(
                    'GET /users (http.Client)',
                    _demoHttpPackage,
                    Colors.teal,
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel('Data Generator'),
                  _demoButton(
                    'Generate products',
                    _demoGeneratedData,
                    Colors.deepPurple,
                  ),
                ],
              ),
            ),
          ),
          // ── Right panel: output ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Response',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_loading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _output,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            color: Colors.greenAccent,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _demoButton(String label, VoidCallback onPressed, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.15),
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.4)),
            alignment: Alignment.centerLeft,
          ),
          onPressed: _loading ? null : onPressed,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );

  String _prettyJson(dynamic obj) {
    const encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(obj);
    } catch (_) {
      return obj.toString();
    }
  }
}
