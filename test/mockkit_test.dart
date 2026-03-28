import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

import 'package:flutter_mockkit/flutter_mockkit.dart';

void main() {
  // Reset MockKit state before every test so tests don't bleed into each other.
  setUp(() {
    MockKit.clearAll();
    MockKit.enable();
    MockKit.disableLogging();
    MockKit.setGlobalDelay(Duration.zero);
  });

  tearDown(() {
    MockKit.disable();
    MockKit.clearAll();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockResponse factory constructors
  // ─────────────────────────────────────────────────────────────────────────
  group('MockResponse factories', () {
    test('ok() sets statusCode to 200', () {
      final r = MockResponse.ok({'key': 'value'});
      expect(r.statusCode, equals(200));
      expect(r.body, equals({'key': 'value'}));
    });

    test('created() sets statusCode to 201', () {
      final r = MockResponse.created({'id': 1});
      expect(r.statusCode, equals(201));
    });

    test('notFound() sets statusCode to 404', () {
      final r = MockResponse.notFound();
      expect(r.statusCode, equals(404));
    });

    test('serverError() sets statusCode to 500', () {
      final r = MockResponse.serverError();
      expect(r.statusCode, equals(500));
    });

    test('unauthorized() sets statusCode to 401', () {
      final r = MockResponse.unauthorized();
      expect(r.statusCode, equals(401));
    });

    test('badRequest() sets statusCode to 400', () {
      final r = MockResponse.badRequest(message: 'Missing field');
      expect(r.statusCode, equals(400));
    });

    test('networkFailure() sets shouldFail to true', () {
      final r = MockResponse.networkFailure();
      expect(r.shouldFail, isTrue);
    });

    test('bodyAsString encodes Map to JSON', () {
      final r = MockResponse.ok({'a': 1});
      expect(r.bodyAsString, equals('{"a":1}'));
    });

    test('bodyAsString returns String body unchanged', () {
      final r = MockResponse(statusCode: 200, body: 'plain text');
      expect(r.bodyAsString, equals('plain text'));
    });

    test('bodyAsString returns empty string for null body', () {
      final r = MockResponse(statusCode: 204);
      expect(r.bodyAsString, equals(''));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockRoute path matching
  // ─────────────────────────────────────────────────────────────────────────
  group('MockRoute.matchPath', () {
    test('exact path matches', () {
      final route = MockRoute(
        method: HttpMethod.get,
        path: '/users',
        response: MockResponse.ok({}),
      );
      expect(route.matchPath('/users'), isNotNull);
    });

    test('exact path non-match returns null', () {
      final route = MockRoute(
        method: HttpMethod.get,
        path: '/users',
        response: MockResponse.ok({}),
      );
      expect(route.matchPath('/posts'), isNull);
    });

    test('parameterised path extracts parameters', () {
      final route = MockRoute(
        method: HttpMethod.get,
        path: '/users/:id',
        response: MockResponse.ok({}),
      );
      final params = route.matchPath('/users/42');
      expect(params, equals({'id': '42'}));
    });

    test('parameterised path non-match returns null for segment count diff', () {
      final route = MockRoute(
        method: HttpMethod.get,
        path: '/users/:id',
        response: MockResponse.ok({}),
      );
      expect(route.matchPath('/users/42/posts'), isNull);
    });

    test('multi-param path extracts all parameters', () {
      final route = MockRoute(
        method: HttpMethod.get,
        path: '/users/:userId/posts/:postId',
        response: MockResponse.ok({}),
      );
      final params = route.matchPath('/users/1/posts/99');
      expect(params, equals({'userId': '1', 'postId': '99'}));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockKit – registration and retrieval
  // ─────────────────────────────────────────────────────────────────────────
  group('MockKit registration', () {
    test('registers a route and returns it in routes list', () {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/ping',
        response: MockResponse.ok({'status': 'ok'}),
      ));
      expect(MockKit.routes.length, equals(1));
    });

    test('registerAll registers multiple routes', () {
      MockKit.registerAll([
        MockRoute(
          method: HttpMethod.get,
          path: '/a',
          response: MockResponse.ok({}),
        ),
        MockRoute(
          method: HttpMethod.post,
          path: '/b',
          response: MockResponse.created({}),
        ),
      ]);
      expect(MockKit.routes.length, equals(2));
    });

    test('duplicate registration replaces previous route', () {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/ping',
        response: MockResponse.ok({'v': 1}),
      ));
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/ping',
        response: MockResponse.ok({'v': 2}),
      ));
      expect(MockKit.routes.length, equals(1));
    });

    test('unregister removes the matching route', () {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/temp',
        response: MockResponse.ok({}),
      ));
      MockKit.unregister(HttpMethod.get, '/temp');
      expect(MockKit.routes, isEmpty);
    });

    test('clearAll removes all routes', () {
      MockKit.registerAll([
        MockRoute(
          method: HttpMethod.get,
          path: '/x',
          response: MockResponse.ok({}),
        ),
        MockRoute(
          method: HttpMethod.post,
          path: '/y',
          response: MockResponse.ok({}),
        ),
      ]);
      MockKit.clearAll();
      expect(MockKit.routes, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockKit.resolve
  // ─────────────────────────────────────────────────────────────────────────
  group('MockKit.resolve', () {
    test('returns null when mock mode is disabled', () async {
      MockKit.disable();
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/ping',
        response: MockResponse.ok({}),
      ));
      final result = await MockKit.resolve(HttpMethod.get, '/ping');
      expect(result, isNull);
    });

    test('returns mock response for a matching route', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/ping',
        response: MockResponse.ok({'status': 'ok'}),
      ));
      final result = await MockKit.resolve(HttpMethod.get, '/ping');
      expect(result, isNotNull);
      expect(result!.statusCode, equals(200));
      expect(result.body, equals({'status': 'ok'}));
    });

    test('returns null for unregistered route', () async {
      final result = await MockKit.resolve(HttpMethod.get, '/unknown');
      expect(result, isNull);
    });

    test('strips query string before matching', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/search',
        response: MockResponse.ok({'results': []}),
      ));
      final result = await MockKit.resolve(
        HttpMethod.get,
        '/search?q=flutter',
        queryParameters: {'q': 'flutter'},
      );
      expect(result, isNotNull);
    });

    test('throws MockNetworkException for failure routes', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/fail',
        response: MockResponse.networkFailure(message: 'Oops'),
      ));
      expect(
        () async => MockKit.resolve(HttpMethod.get, '/fail'),
        throwsA(isA<MockNetworkException>()),
      );
    });

    test('method mismatch returns null', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.post,
        path: '/users',
        response: MockResponse.created({}),
      ));
      final result = await MockKit.resolve(HttpMethod.get, '/users');
      expect(result, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Dynamic response builder
  // ─────────────────────────────────────────────────────────────────────────
  group('Dynamic responseBuilder', () {
    test('receives path parameters', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/users/:id',
        responseBuilder: (req) {
          final id = req.pathParameters['id']!;
          return MockResponse.ok({'id': id, 'name': 'User $id'});
        },
      ));

      final result = await MockKit.resolve(HttpMethod.get, '/users/7');
      expect(result, isNotNull);
      expect(result!.body['id'], equals('7'));
      expect(result.body['name'], equals('User 7'));
    });

    test('receives query parameters', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/search',
        responseBuilder: (req) {
          final q = req.queryParameters['q'] ?? '';
          return MockResponse.ok({'query': q, 'results': []});
        },
      ));

      final result = await MockKit.resolve(
        HttpMethod.get,
        '/search',
        queryParameters: {'q': 'dart'},
      );
      expect(result!.body['query'], equals('dart'));
    });

    test('receives request body', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.post,
        path: '/echo',
        responseBuilder: (req) {
          final body = req.bodyAsJson;
          return MockResponse.ok({'echo': body});
        },
      ));

      final result = await MockKit.resolve(
        HttpMethod.post,
        '/echo',
        body: jsonEncode({'message': 'hello'}),
      );
      expect(result!.body['echo']['message'], equals('hello'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Delay simulation
  // ─────────────────────────────────────────────────────────────────────────
  group('Delay simulation', () {
    test('per-route delay is respected', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/slow',
        response: MockResponse.ok({}, delay: const Duration(milliseconds: 100)),
      ));

      final start = DateTime.now();
      await MockKit.resolve(HttpMethod.get, '/slow');
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('global delay is added to per-route delay', () async {
      MockKit.setGlobalDelay(const Duration(milliseconds: 50));
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/slow2',
        response: MockResponse.ok({}, delay: const Duration(milliseconds: 50)),
      ));

      final start = DateTime.now();
      await MockKit.resolve(HttpMethod.get, '/slow2');
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(100));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockHttpClient  (http package integration)
  // ─────────────────────────────────────────────────────────────────────────
  group('MockHttpClient', () {
    late MockHttpClient client;

    setUp(() {
      client = MockHttpClient();
    });

    tearDown(() {
      client.close();
    });

    test('GET request returns mocked response body', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/users',
        response: MockResponse.ok({'users': []}),
      ));

      final response = await client.get(
        Uri.parse('https://api.example.com/users'),
      );
      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body);
      expect(body['users'], isA<List>());
    });

    test('POST request returns mocked 201 response', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.post,
        path: '/users',
        response: MockResponse.created({'id': 99}),
      ));

      final response = await client.post(
        Uri.parse('https://api.example.com/users'),
        body: jsonEncode({'name': 'Alice'}),
        headers: {'Content-Type': 'application/json'},
      );
      expect(response.statusCode, equals(201));
    });

    test('DELETE request returns mocked response', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.delete,
        path: '/users/1',
        response: MockResponse(statusCode: 204),
      ));

      final response = await client.delete(
        Uri.parse('https://api.example.com/users/1'),
      );
      expect(response.statusCode, equals(204));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockDioInterceptor  (Dio integration)
  // ─────────────────────────────────────────────────────────────────────────
  group('MockDioInterceptor', () {
    late Dio dio;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.interceptors.add(MockDioInterceptor());
    });

    test('GET request returns mocked data', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/products',
        response: MockResponse.ok([{'id': 1}]),
      ));

      final response = await dio.get('/products');
      expect(response.statusCode, equals(200));
      expect(response.data, isA<List>());
    });

    test('POST request returns mocked 201', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.post,
        path: '/products',
        response: MockResponse.created({'id': 5, 'name': 'Widget'}),
      ));

      final response = await dio.post('/products', data: {'name': 'Widget'});
      expect(response.statusCode, equals(201));
      expect(response.data['id'], equals(5));
    });

    test('network failure route throws DioException', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/broken',
        response: MockResponse.networkFailure(),
      ));

      expect(
        () async => dio.get('/broken'),
        throwsA(isA<DioException>()),
      );
    });

    test('parameterised route works with Dio', () async {
      MockKit.register(MockRoute(
        method: HttpMethod.get,
        path: '/products/:id',
        responseBuilder: (req) {
          final id = req.pathParameters['id']!;
          return MockResponse.ok({'id': id, 'name': 'Product $id'});
        },
      ));

      final response = await dio.get('/products/42');
      expect(response.data['name'], equals('Product 42'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockDataGenerator
  // ─────────────────────────────────────────────────────────────────────────
  group('MockDataGenerator', () {
    test('fromJson wraps map in MockResponse', () {
      final resp = MockDataGenerator.fromJson({'token': 'abc'});
      expect(resp.statusCode, equals(200));
      expect(resp.body['token'], equals('abc'));
    });

    test('fromSchema generates a map with correct keys', () {
      final schema = {
        'id': 'uuid',
        'name': 'name',
        'email': 'email',
        'age': 'int',
        'score': 'double',
        'active': 'bool',
        'joined': 'date',
      };
      final result = MockDataGenerator.fromSchema(schema);
      expect(result.keys, containsAll(schema.keys));
    });

    test('fromSchema "int" generates an integer', () {
      final result = MockDataGenerator.fromSchema({'count': 'int'});
      expect(result['count'], isA<int>());
    });

    test('fromSchema "double" generates a double', () {
      final result = MockDataGenerator.fromSchema({'score': 'double'});
      expect(result['score'], isA<double>());
    });

    test('fromSchema "bool" generates a boolean', () {
      final result = MockDataGenerator.fromSchema({'active': 'bool'});
      expect(result['active'], isA<bool>());
    });

    test('fromSchema "uuid" generates a non-empty string', () {
      final result = MockDataGenerator.fromSchema({'id': 'uuid'});
      expect(result['id'], isA<String>());
      expect((result['id'] as String).isNotEmpty, isTrue);
    });

    test('listFromSchema generates correct number of items', () {
      final list = MockDataGenerator.listFromSchema(
        {'id': 'uuid', 'name': 'name'},
        count: 7,
      );
      expect(list.length, equals(7));
    });

    test('paginatedList returns correct envelope keys', () {
      final page = MockDataGenerator.paginatedList(
        schema: {'id': 'uuid', 'title': 'string'},
        page: 2,
        perPage: 5,
        total: 20,
      );
      expect(page.containsKey('data'), isTrue);
      expect(page.containsKey('pagination'), isTrue);
      expect(page['pagination']['page'], equals(2));
      expect((page['data'] as List).length, equals(5));
    });

    test('uuid() produces a 36-character string', () {
      final id = MockDataGenerator.uuid();
      expect(id.length, equals(36));
    });

    test('email() contains @', () {
      final e = MockDataGenerator.email();
      expect(e.contains('@'), isTrue);
    });

    test('hexColor() starts with #', () {
      final color = MockDataGenerator.hexColor();
      expect(color.startsWith('#'), isTrue);
      expect(color.length, equals(7));
    });

    test('randomInt respects min/max bounds', () {
      for (var i = 0; i < 20; i++) {
        final v = MockDataGenerator.randomInt(min: 10, max: 20);
        expect(v, greaterThanOrEqualTo(10));
        expect(v, lessThanOrEqualTo(20));
      }
    });

    test('pickOne returns an element from the list', () {
      final items = ['a', 'b', 'c'];
      final picked = MockDataGenerator.pickOne(items);
      expect(items.contains(picked), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MockKit – global mode toggle
  // ─────────────────────────────────────────────────────────────────────────
  group('MockKit mode toggle', () {
    test('enable() and disable() toggle isEnabled', () {
      MockKit.enable();
      expect(MockKit.isEnabled, isTrue);
      MockKit.disable();
      expect(MockKit.isEnabled, isFalse);
    });

    test('logging toggle works', () {
      MockKit.enableLogging();
      expect(MockKit.isLoggingEnabled, isTrue);
      MockKit.disableLogging();
      expect(MockKit.isLoggingEnabled, isFalse);
    });

    test('setGlobalDelay persists', () {
      MockKit.setGlobalDelay(const Duration(seconds: 2));
      expect(MockKit.globalDelay, equals(const Duration(seconds: 2)));
      MockKit.setGlobalDelay(Duration.zero);
    });
  });
}
