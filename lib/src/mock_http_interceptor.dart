import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import 'mock_registry.dart';

// ---------------------------------------------------------------------------
// MockHttpClient  (drop-in replacement for http.Client)
// ---------------------------------------------------------------------------

/// A drop-in replacement for [http.Client] that intercepts outgoing requests
/// and returns registered [MockResponse]s when [MockKit] is enabled.
///
/// When mock mode is **disabled** (or no route matches), every call is
/// transparently forwarded to the real [http.Client] provided at construction
/// time (or a default [http.Client] if none is supplied).
///
/// ### Usage
/// ```dart
/// final client = MockHttpClient();
///
/// MockKit.enable();
/// MockKit.register(MockRoute(
///   method: HttpMethod.get,
///   path: '/users',
///   response: MockResponse.ok({'users': []}),
/// ));
///
/// final response = await client.get(Uri.parse('https://api.example.com/users'));
/// print(response.body); // {"users":[]}
/// ```
class MockHttpClient extends http.BaseClient {
  /// The real [http.Client] used when mock mode is disabled or no route matches.
  final http.Client _inner;

  /// Creates a [MockHttpClient].
  ///
  /// Optionally provide a custom [inner] client (useful for testing the
  /// pass-through behaviour with a [MockClient]).
  MockHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = _httpMethodFromString(request.method);
    if (method == null) return _inner.send(request);

    final uri = request.url;
    String? bodyString;

    if (request is http.Request) {
      bodyString = request.body.isNotEmpty ? request.body : null;
    }

    final mockResponse = await MockKit.resolve(
      method,
      uri.path,
      queryParameters: uri.queryParameters,
      headers: Map<String, String>.from(request.headers),
      body: bodyString,
    );

    if (mockResponse == null) return _inner.send(request);

    final bodyBytes = utf8.encode(mockResponse.bodyAsString);
    return http.StreamedResponse(
      Stream.value(bodyBytes),
      mockResponse.statusCode,
      headers: mockResponse.headers,
      request: request,
    );
  }

  /// Maps a raw HTTP method string to the corresponding [HttpMethod] enum
  /// value, returning `null` for unrecognised verbs.
  HttpMethod? _httpMethodFromString(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PUT':
        return HttpMethod.put;
      case 'DELETE':
        return HttpMethod.delete;
      case 'PATCH':
        return HttpMethod.patch;
      default:
        return null;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// ---------------------------------------------------------------------------
// MockDioInterceptor  (Dio interceptor)
// ---------------------------------------------------------------------------

/// A [Dio] interceptor that short-circuits HTTP requests and returns
/// registered [MockResponse]s when [MockKit] is enabled.
///
/// Add it to a [Dio] instance **before** any other interceptors so that mocked
/// routes are resolved first.
///
/// ### Usage
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(MockDioInterceptor());
///
/// MockKit.enable();
/// MockKit.register(MockRoute(
///   method: HttpMethod.post,
///   path: '/login',
///   response: MockResponse.ok({'token': 'abc123'}),
/// ));
///
/// final resp = await dio.post('https://api.example.com/login',
///     data: {'username': 'alice', 'password': 'secret'});
/// print(resp.data); // {token: abc123}
/// ```
class MockDioInterceptor extends Interceptor {
  /// Creates a [MockDioInterceptor].
  MockDioInterceptor();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final method = _dioMethodFromString(options.method);
    if (method == null) {
      handler.next(options);
      return;
    }

    // Extract body as string
    String? bodyString;
    if (options.data != null) {
      if (options.data is String) {
        bodyString = options.data as String;
      } else {
        try {
          bodyString = jsonEncode(options.data);
        } catch (_) {
          bodyString = options.data.toString();
        }
      }
    }

    // Build query parameters map
    final queryParams = options.queryParameters.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    try {
      final mockResponse = await MockKit.resolve(
        method,
        options.uri.path,
        queryParameters: queryParams,
        headers: Map<String, String>.from(
          options.headers.map((k, v) => MapEntry(k.toString(), v.toString())),
        ),
        body: bodyString,
      );

      if (mockResponse == null) {
        handler.next(options);
        return;
      }

      // Decode body for Dio (it expects an already-decoded object for JSON)
      dynamic decodedBody;
      if (mockResponse.body is String) {
        try {
          decodedBody = jsonDecode(mockResponse.body as String);
        } catch (_) {
          decodedBody = mockResponse.body;
        }
      } else {
        decodedBody = mockResponse.body;
      }

      handler.resolve(
        Response(
          requestOptions: options,
          data: decodedBody,
          statusCode: mockResponse.statusCode,
          headers: Headers.fromMap(
            mockResponse.headers.map((k, v) => MapEntry(k, [v])),
          ),
          statusMessage:
              mockResponse.statusCode >= 200 &&
                      mockResponse.statusCode < 300
                  ? 'OK'
                  : 'Error',
        ),
      );
    } on MockNetworkException catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          message: e.message,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  HttpMethod? _dioMethodFromString(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PUT':
        return HttpMethod.put;
      case 'DELETE':
        return HttpMethod.delete;
      case 'PATCH':
        return HttpMethod.patch;
      default:
        return null;
    }
  }
}
