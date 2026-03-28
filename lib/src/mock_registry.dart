import 'dart:async';
import 'dart:convert';

/// Supported HTTP methods for mock route registration.
enum HttpMethod { get, post, put, delete, patch }

/// Extension to convert [HttpMethod] to its string representation.
extension HttpMethodExtension on HttpMethod {
  /// Returns the uppercase HTTP verb string, e.g. `"GET"`.
  String get value => name.toUpperCase();
}

// ---------------------------------------------------------------------------
// MockResponse
// ---------------------------------------------------------------------------

/// Represents a simulated HTTP response returned by a registered mock route.
///
/// ### Example
/// ```dart
/// final response = MockResponse(
///   statusCode: 200,
///   body: {'id': 1, 'name': 'Alice'},
///   headers: {'Content-Type': 'application/json'},
///   delay: Duration(milliseconds: 300),
/// );
/// ```
class MockResponse {
  /// HTTP status code for this response. Defaults to `200`.
  final int statusCode;

  /// The response body. Can be a `Map`, `List`, `String`, or `null`.
  final dynamic body;

  /// Optional HTTP response headers.
  final Map<String, String> headers;

  /// Artificial delay to simulate network latency. Defaults to [Duration.zero].
  final Duration delay;

  /// If `true`, this response will throw a [MockNetworkException] instead of
  /// returning a successful response — useful for testing error-handling code.
  final bool shouldFail;

  /// Optional custom failure message when [shouldFail] is `true`.
  final String? failureMessage;

  /// Creates a [MockResponse].
  ///
  /// - [statusCode] defaults to `200`.
  /// - [body] can be any JSON-serialisable object.
  /// - [delay] defaults to `Duration.zero` (no artificial latency).
  /// - [shouldFail] defaults to `false`.
  const MockResponse({
    this.statusCode = 200,
    this.body,
    this.headers = const {'Content-Type': 'application/json'},
    this.delay = Duration.zero,
    this.shouldFail = false,
    this.failureMessage,
  });

  /// Convenience factory for a `200 OK` response with a JSON body.
  factory MockResponse.ok(dynamic body, {Duration delay = Duration.zero}) {
    return MockResponse(statusCode: 200, body: body, delay: delay);
  }

  /// Convenience factory for a `201 Created` response.
  factory MockResponse.created(dynamic body, {Duration delay = Duration.zero}) {
    return MockResponse(statusCode: 201, body: body, delay: delay);
  }

  /// Convenience factory for a `400 Bad Request` response.
  factory MockResponse.badRequest({
    String message = 'Bad Request',
    Duration delay = Duration.zero,
  }) {
    return MockResponse(
      statusCode: 400,
      body: {'error': message},
      delay: delay,
    );
  }

  /// Convenience factory for a `401 Unauthorized` response.
  factory MockResponse.unauthorized({Duration delay = Duration.zero}) {
    return MockResponse(
      statusCode: 401,
      body: {'error': 'Unauthorized'},
      delay: delay,
    );
  }

  /// Convenience factory for a `404 Not Found` response.
  factory MockResponse.notFound({Duration delay = Duration.zero}) {
    return MockResponse(
      statusCode: 404,
      body: {'error': 'Not Found'},
      delay: delay,
    );
  }

  /// Convenience factory for a `500 Internal Server Error` response.
  factory MockResponse.serverError({
    String message = 'Internal Server Error',
    Duration delay = Duration.zero,
  }) {
    return MockResponse(
      statusCode: 500,
      body: {'error': message},
      delay: delay,
    );
  }

  /// Convenience factory for a network-failure simulation (throws an
  /// exception rather than returning an HTTP response).
  factory MockResponse.networkFailure({
    String message = 'Simulated network failure',
    Duration delay = Duration.zero,
  }) {
    return MockResponse(
      statusCode: 0,
      shouldFail: true,
      failureMessage: message,
      delay: delay,
    );
  }

  /// Serialises [body] to a JSON string.
  String get bodyAsString {
    if (body == null) return '';
    if (body is String) return body as String;
    return jsonEncode(body);
  }
}

// ---------------------------------------------------------------------------
// MockRequest (context passed to dynamic-response handlers)
// ---------------------------------------------------------------------------

/// Snapshot of an intercepted HTTP request, passed to dynamic-response
/// handlers so they can inspect path, query params, and body before deciding
/// what [MockResponse] to return.
class MockRequest {
  /// The full request path, e.g. `/users/42`.
  final String path;

  /// The HTTP method of the intercepted request.
  final HttpMethod method;

  /// Query parameters parsed from the URL, e.g. `{'page': '2'}`.
  final Map<String, String> queryParameters;

  /// Request headers sent by the client.
  final Map<String, String> headers;

  /// The raw request body string (may be empty for GET/DELETE).
  final String? body;

  /// Path parameters extracted from a parameterised route, e.g.
  /// for the pattern `/users/:id` with path `/users/42` →  `{'id': '42'}`.
  final Map<String, String> pathParameters;

  /// Creates a [MockRequest].
  const MockRequest({
    required this.path,
    required this.method,
    this.queryParameters = const {},
    this.headers = const {},
    this.body,
    this.pathParameters = const {},
  });

  /// Returns [body] decoded as a `Map<String, dynamic>`, or an empty map if
  /// the body is absent or not valid JSON.
  Map<String, dynamic> get bodyAsJson {
    if (body == null || body!.isEmpty) return {};
    try {
      final decoded = jsonDecode(body!);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }
}

// ---------------------------------------------------------------------------
// MockRoute
// ---------------------------------------------------------------------------

/// A registered mock route that pairs an HTTP method + path pattern with
/// either a static [MockResponse] or a dynamic response builder function.
///
/// ### Static example
/// ```dart
/// MockRoute(
///   method: HttpMethod.get,
///   path: '/users',
///   response: MockResponse.ok({'users': []}),
/// )
/// ```
///
/// ### Dynamic example
/// ```dart
/// MockRoute(
///   method: HttpMethod.get,
///   path: '/users/:id',
///   responseBuilder: (request) {
///     final id = request.pathParameters['id'];
///     return MockResponse.ok({'id': id, 'name': 'User $id'});
///   },
/// )
/// ```
class MockRoute {
  /// The HTTP method this route matches.
  final HttpMethod method;

  /// The path pattern to match. Supports named parameters with `:name`
  /// notation, e.g. `/users/:id`.
  final String path;

  /// A static response returned for every matching request.
  /// Mutually exclusive with [responseBuilder].
  final MockResponse? response;

  /// A dynamic response builder invoked with a [MockRequest] snapshot.
  /// Mutually exclusive with [response].
  final MockResponse Function(MockRequest request)? responseBuilder;

  /// Optional description for debugging / logging purposes.
  final String? description;

  /// Creates a [MockRoute].
  ///
  /// Exactly one of [response] or [responseBuilder] must be provided.
  MockRoute({
    required this.method,
    required this.path,
    this.response,
    this.responseBuilder,
    this.description,
  }) : assert(
         response != null || responseBuilder != null,
         'A MockRoute must have either a response or a responseBuilder.',
       );

  /// Attempts to match [requestPath] against this route's [path] pattern.
  ///
  /// Returns a map of extracted path parameters if matched, or `null` if the
  /// paths do not match.
  Map<String, String>? matchPath(String requestPath) {
    final patternSegments = path.split('/');
    final requestSegments = requestPath.split('/');

    if (patternSegments.length != requestSegments.length) return null;

    final params = <String, String>{};
    for (var i = 0; i < patternSegments.length; i++) {
      final pattern = patternSegments[i];
      final actual = requestSegments[i];
      if (pattern.startsWith(':')) {
        params[pattern.substring(1)] = actual;
      } else if (pattern != actual) {
        return null;
      }
    }
    return params;
  }
}

// ---------------------------------------------------------------------------
// MockNetworkException
// ---------------------------------------------------------------------------

/// Thrown when a registered mock route has [MockResponse.shouldFail] set to
/// `true`, simulating a hard network failure (e.g. no internet connection).
class MockNetworkException implements Exception {
  /// Human-readable description of the simulated failure.
  final String message;

  /// Creates a [MockNetworkException] with the given [message].
  const MockNetworkException(this.message);

  @override
  String toString() => 'MockNetworkException: $message';
}

// ---------------------------------------------------------------------------
// MockKit  (central registry + mode switch)
// ---------------------------------------------------------------------------

/// The central façade for `flutter_mockkit`.
///
/// Use [MockKit] to register routes, toggle mock/live mode, and configure
/// global behaviour such as default latency and verbose logging.
///
/// ### Basic setup
/// ```dart
/// void main() {
///   MockKit.enable();
///
///   MockKit.register(
///     MockRoute(
///       method: HttpMethod.get,
///       path: '/ping',
///       response: MockResponse.ok({'status': 'ok'}),
///     ),
///   );
///
///   runApp(MyApp());
/// }
/// ```
class MockKit {
  MockKit._();

  static final List<MockRoute> _routes = [];
  static bool _enabled = false;
  static bool _verboseLogging = false;
  static Duration _globalDelay = Duration.zero;

  // ── Mode control ──────────────────────────────────────────────────────────

  /// Enables mock mode. All intercepted requests will be matched against
  /// registered [MockRoute]s instead of hitting real network endpoints.
  static void enable() => _enabled = true;

  /// Disables mock mode. Interceptors pass requests through to the real network.
  static void disable() => _enabled = false;

  /// Whether mock mode is currently active.
  static bool get isEnabled => _enabled;

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Enables verbose console logging for every intercepted request and its
  /// matched mock response. Useful during development.
  static void enableLogging() => _verboseLogging = true;

  /// Disables verbose console logging.
  static void disableLogging() => _verboseLogging = false;

  /// Whether verbose logging is active.
  static bool get isLoggingEnabled => _verboseLogging;

  /// Sets a global artificial delay applied to **all** mock responses in
  /// addition to any per-route [MockResponse.delay].
  static void setGlobalDelay(Duration delay) => _globalDelay = delay;

  /// The current global delay added to every mock response.
  static Duration get globalDelay => _globalDelay;

  // ── Route management ──────────────────────────────────────────────────────

  /// Registers a single [MockRoute].
  ///
  /// Later registrations for the same method + path pattern override earlier
  /// ones (last-write-wins semantics).
  static void register(MockRoute route) {
    _routes.removeWhere(
      (r) => r.method == route.method && r.path == route.path,
    );
    _routes.add(route);
    _log('Registered mock: ${route.method.value} ${route.path}');
  }

  /// Registers multiple [MockRoute]s in one call.
  static void registerAll(List<MockRoute> routes) {
    for (final route in routes) {
      register(route);
    }
  }

  /// Removes a previously registered route by method + path.
  static void unregister(HttpMethod method, String path) {
    _routes.removeWhere((r) => r.method == method && r.path == path);
    _log('Unregistered mock: ${method.value} $path');
  }

  /// Removes **all** registered routes.
  static void clearAll() {
    _routes.clear();
    _log('All mocks cleared.');
  }

  /// Returns an unmodifiable view of all currently registered routes.
  static List<MockRoute> get routes => List.unmodifiable(_routes);

  // ── Request resolution ────────────────────────────────────────────────────

  /// Resolves a mock response for the given [method] and [requestPath], or
  /// returns `null` if no matching route exists.
  ///
  /// The method first strips any query string from [requestPath] before
  /// performing the pattern match.
  static Future<MockResponse?> resolve(
    HttpMethod method,
    String requestPath, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
    String? body,
  }) async {
    if (!_enabled) return null;

    // Strip query string from path for matching
    final cleanPath = requestPath.split('?').first;

    for (final route in _routes.reversed) {
      if (route.method != method) continue;
      final pathParams = route.matchPath(cleanPath);
      if (pathParams == null) continue;

      final request = MockRequest(
        path: cleanPath,
        method: method,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
        pathParameters: pathParams,
      );

      final rawResponse =
          route.responseBuilder != null
              ? route.responseBuilder!(request)
              : route.response!;

      // Apply delays: per-route delay + global delay
      final totalDelay = rawResponse.delay + _globalDelay;
      if (totalDelay > Duration.zero) {
        await Future.delayed(totalDelay);
      }

      if (rawResponse.shouldFail) {
        _log(
          '[FAIL] ${method.value} $requestPath → '
          '${rawResponse.failureMessage}',
        );
        throw MockNetworkException(
          rawResponse.failureMessage ?? 'Simulated network failure',
        );
      }

      _log(
        '[MOCK] ${method.value} $requestPath → ${rawResponse.statusCode}',
      );
      return rawResponse;
    }

    _log('[MOCK] No route matched: ${method.value} $requestPath');
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static void _log(String message) {
    if (_verboseLogging) {
      // ignore: avoid_print
      print('[MockKit] $message');
    }
  }
}
