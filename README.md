# flutter_mockkit

[![pub.dev](https://img.shields.io/pub/v/flutter_mockkit.svg)](https://pub.dev/packages/flutter_mockkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10.0-blue.svg)](https://flutter.dev)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0.0-blue.svg)](https://dart.dev)

> **A lightweight, developer-friendly toolkit to mock API requests and responses in Flutter apps during development.**

Stop waiting for a backend. With `flutter_mockkit` you can:

- **Intercept** every HTTP call from `http` and `dio` clients.
- **Return** static or dynamically computed responses.
- **Simulate** realistic network latency and hard failures.
- **Toggle** between mock and live mode with a single line of code.
- **Generate** realistic fake data from a JSON schema — no extra dependencies.

---

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Usage Guide](#usage-guide)
   - [Enabling / Disabling Mock Mode](#1-enabling--disabling-mock-mode)
   - [Basic GET Mock](#2-basic-get-mock)
   - [Basic POST Mock](#3-basic-post-mock)
   - [Dynamic Responses](#4-dynamic-responses)
   - [Path Parameters](#5-path-parameters)
   - [Simulated Latency](#6-simulated-latency)
   - [Error Simulation](#7-error-simulation)
   - [Network Failure Simulation](#8-network-failure-simulation)
   - [Using with `http` package](#9-using-with-the-http-package)
   - [Using with `dio`](#10-using-with-dio)
   - [Auto-Generating Mock Data](#11-auto-generating-mock-data)
   - [Verbose Logging](#12-verbose-logging)
5. [API Reference](#api-reference)
6. [Publishing to pub.dev](#publishing-to-pubdev)
7. [Contributing](#contributing)
8. [License](#license)

---

## Features

| Feature | Description |
|---|---|
| 🔀 **Mock / Live Toggle** | `MockKit.enable()` / `MockKit.disable()` — flip the switch globally. |
| 🌐 **http & dio Support** | `MockHttpClient` and `MockDioInterceptor` are drop-in replacements. |
| ⚡ **Dynamic Responses** | Pass a `responseBuilder` function to compute responses at request time. |
| 🛣️ **Path Parameters** | Routes like `/users/:id` extract params automatically. |
| ⏳ **Delay Simulation** | Per-route and global artificial latency. |
| 💥 **Error Simulation** | Return 4xx/5xx or throw network exceptions deterministically. |
| 🧬 **Data Generator** | Generate fake users, products, UUIDs, emails — from a schema map. |
| 📋 **Paginated Lists** | One-liner helper for paginated REST list responses. |
| 🐛 **Verbose Logging** | Opt-in console log for every intercepted request and its outcome. |

---

## Installation

Add `flutter_mockkit` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_mockkit: ^1.0.0
```

Then run:

```bash
flutter pub get
```

> **Tip:** Consider adding this only to `dev_dependencies` if you wrap the
> mock setup behind a build-time flag so mocks are never shipped to production.

---

## Quick Start

```dart
import 'package:flutter_mockkit/flutter_mockkit.dart';
import 'package:dio/dio.dart';

void main() {
  // 1. Enable mock mode
  MockKit.enable();

  // 2. Register a mock route
  MockKit.register(MockRoute(
    method: HttpMethod.get,
    path: '/users',
    response: MockResponse.ok({'users': [{'id': 1, 'name': 'Alice'}]}),
  ));

  // 3. Attach the interceptor to your Dio client
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(MockDioInterceptor());

  runApp(MyApp(dio: dio));
}
```

That's it — every `GET /users` call now returns your mock data, zero network
traffic involved.

---

## Usage Guide

### 1. Enabling / Disabling Mock Mode

```dart
// Enable – all registered mocks are active
MockKit.enable();

// Disable – requests pass through to the real network
MockKit.disable();

// Check current state
print(MockKit.isEnabled); // true / false
```

A common pattern is to gate this on your build mode:

```dart
if (kDebugMode) MockKit.enable();
```

---

### 2. Basic GET Mock

```dart
MockKit.register(MockRoute(
  method: HttpMethod.get,
  path: '/products',
  description: 'Returns the product catalogue', // optional — for your notes
  response: MockResponse.ok([
    {'id': 1, 'name': 'Widget A', 'price': 9.99},
    {'id': 2, 'name': 'Widget B', 'price': 19.99},
  ]),
));
```

**Convenience response factories:**

```dart
MockResponse.ok(body)            // 200
MockResponse.created(body)       // 201
MockResponse.badRequest()        // 400
MockResponse.unauthorized()      // 401
MockResponse.notFound()          // 404
MockResponse.serverError()       // 500
MockResponse.networkFailure()    // throws MockNetworkException
```

---

### 3. Basic POST Mock

```dart
MockKit.register(MockRoute(
  method: HttpMethod.post,
  path: '/products',
  response: MockResponse.created({'id': 42, 'name': 'New Widget'}),
));
```

---

### 4. Dynamic Responses

Use a `responseBuilder` to inspect the request before deciding what to return.
The builder receives a `MockRequest` with `body`, `queryParameters`,
`headers`, and `pathParameters` already parsed.

```dart
MockKit.register(MockRoute(
  method: HttpMethod.post,
  path: '/login',
  responseBuilder: (request) {
    final body = request.bodyAsJson; // Map<String, dynamic>

    if (body['password'] == 'secret') {
      return MockResponse.ok({'token': 'jwt-abc-123'});
    }

    return MockResponse.unauthorized();
  },
));
```

---

### 5. Path Parameters

Routes support `:name` style path parameters. They are extracted and passed
into `MockRequest.pathParameters`.

```dart
// Route: /users/:id
MockKit.register(MockRoute(
  method: HttpMethod.get,
  path: '/users/:id',
  responseBuilder: (request) {
    final id = request.pathParameters['id']!; // '42'
    return MockResponse.ok({'id': id, 'name': 'User $id'});
  },
));

// Matches:
//   GET /users/1
//   GET /users/42
//   GET /users/abc123
```

Multi-segment parameters also work:

```dart
MockKit.register(MockRoute(
  method: HttpMethod.get,
  path: '/teams/:teamId/members/:memberId',
  responseBuilder: (request) {
    return MockResponse.ok({
      'team': request.pathParameters['teamId'],
      'member': request.pathParameters['memberId'],
    });
  },
));
```

---

### 6. Simulated Latency

#### Per-route delay

```dart
MockKit.register(MockRoute(
  method: HttpMethod.get,
  path: '/reports/annual',
  response: MockResponse.ok(
    {'report': 'data…'},
    delay: const Duration(seconds: 2), // simulate a slow query
  ),
));
```

#### Global delay (added to every response)

```dart
// Add 300 ms to every mock response — great for testing loading states
MockKit.setGlobalDelay(const Duration(milliseconds: 300));
```

---

### 7. Error Simulation

Return any 4xx / 5xx status code to test your error-handling UI:

```dart
// 503 Service Unavailable
MockKit.register(MockRoute(
  method: HttpMethod.get,
  path: '/maintenance',
  response: MockResponse(
    statusCode: 503,
    body: {'message': 'Under maintenance'},
  ),
));
```

Use the built-in factories for the most common cases:

```dart
MockResponse.notFound()      // 404 {"error": "Not Found"}
MockResponse.serverError()   // 500 {"error": "Internal Server Error"}
MockResponse.unauthorized()  // 401 {"error": "Unauthorized"}
```

---

### 8. Network Failure Simulation

Simulates a hard network failure (throws an exception rather than returning
an HTTP response):

```dart
MockKit.register(MockRoute(
  method: HttpMethod.get,
  path: '/flaky-endpoint',
  response: MockResponse.networkFailure(
    message: 'No internet connection',
  ),
));
```

With `MockHttpClient` this throws a `MockNetworkException`.
With `MockDioInterceptor` this triggers a `DioException`.

Handle it the same way you would handle a real network error:

```dart
try {
  final response = await dio.get('/flaky-endpoint');
} on DioException catch (e) {
  showErrorSnackBar('Network error: ${e.message}');
}
```

---

### 9. Using with the `http` Package

Replace `http.Client()` with `MockHttpClient()` — the API is identical:

```dart
import 'package:http/http.dart' as http;
import 'package:flutter_mockkit/flutter_mockkit.dart';

final http.Client client = MockHttpClient();

final response = await client.get(
  Uri.parse('https://api.example.com/users'),
);

print(response.statusCode); // 200
print(response.body);       // {"users": [...]}
```

When `MockKit.isEnabled` is `false`, or when no matching route is found, every
request is forwarded to the real network via the inner `http.Client`.

---

### 10. Using with Dio

Add `MockDioInterceptor` as the **first** interceptor on your `Dio` instance:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_mockkit/flutter_mockkit.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(MockDioInterceptor()); // ← add first

final response = await dio.get('/users');
print(response.data); // already decoded JSON
```

When mock mode is disabled or no route matches, `MockDioInterceptor` calls
`handler.next(options)` and Dio proceeds normally.

---

### 11. Auto-Generating Mock Data

`MockDataGenerator` turns a simple schema map into realistic fake data.

#### Single object

```dart
final user = MockDataGenerator.fromSchema({
  'id':       'uuid',
  'name':     'name',
  'email':    'email',
  'phone':    'phone',
  'age':      'int',
  'score':    'double',
  'active':   'bool',
  'joined':   'date',
  'profile':  'url',
  'bio':      'paragraph',
});
// {id: 'a1b2…', name: 'Alice Chen', email: 'alice.chen@example.com', …}
```

**Supported type strings:**

| Type string | Example output |
|---|---|
| `"string"` | `"alpha"` |
| `"int"` / `"integer"` | `42` |
| `"double"` / `"float"` | `73.41` |
| `"bool"` / `"boolean"` | `true` |
| `"uuid"` / `"id"` | `"a1b2c3d4-…"` |
| `"name"` | `"Grace Harris"` |
| `"email"` | `"grace.harris@mail.io"` |
| `"phone"` | `"+1-415-555-1234"` |
| `"date"` | `"2022-08-15"` |
| `"datetime"` | `"2022-08-15T09:30:00.000"` |
| `"url"` / `"uri"` | `"https://example.com/api/v1/…"` |
| `"color"` / `"colour"` | `"#A3F2BC"` |
| `"paragraph"` / `"text"` | Short lorem-ipsum sentence(s) |

#### List of objects

```dart
final users = MockDataGenerator.listFromSchema(
  {'id': 'uuid', 'name': 'name', 'email': 'email'},
  count: 10,
);
```

#### Paginated response

```dart
final page = MockDataGenerator.paginatedList(
  schema: {'id': 'uuid', 'title': 'string', 'price': 'double'},
  page: 2,
  perPage: 10,
  total: 57,
);
// {
//   "data": [{…}, {…}, …],
//   "pagination": {
//     "page": 2, "per_page": 10, "total": 57,
//     "total_pages": 6, "has_next": true, "has_prev": true
//   }
// }
```

#### Wrap existing JSON as a MockResponse

```dart
final response = MockDataGenerator.fromJson(
  {'token': 'eyJhbGci…', 'expires_in': 3600},
  statusCode: 200,
  delay: const Duration(milliseconds: 200),
);
```

#### Individual primitive generators

```dart
MockDataGenerator.uuid();                              // "f47ac10b-…"
MockDataGenerator.name();                              // "James Lopez"
MockDataGenerator.email();                             // "james.lopez@test.dev"
MockDataGenerator.phone();                             // "+1-303-721-4892"
MockDataGenerator.date();                              // "2021-03-18"
MockDataGenerator.datetime();                          // "2021-03-18T14:22:00.000"
MockDataGenerator.url();                               // "https://mockserver.io/api/v1/…"
MockDataGenerator.hexColor();                          // "#E4A0F7"
MockDataGenerator.paragraph();                         // "Lorem ipsum dolor…"
MockDataGenerator.randomInt(min: 1, max: 100);         // 57
MockDataGenerator.randomDouble(min: 0.0, max: 10.0);   // 3.74
MockDataGenerator.randomBool();                        // false
MockDataGenerator.pickOne(['a', 'b', 'c']);            // "b"
```

---

### 12. Verbose Logging

Enable during development to see every intercepted call in the console:

```dart
MockKit.enableLogging();

// Console output:
// [MockKit] Registered mock: GET /users
// [MockKit] [MOCK] GET /users → 200
// [MockKit] [FAIL] GET /network-failure → Simulated network failure
```

---

## API Reference

### `MockKit`

| Member | Description |
|---|---|
| `MockKit.enable()` | Activates mock mode. |
| `MockKit.disable()` | Deactivates mock mode; requests hit the real network. |
| `MockKit.isEnabled` | Whether mock mode is active. |
| `MockKit.register(route)` | Registers (or replaces) a `MockRoute`. |
| `MockKit.registerAll(routes)` | Registers a list of `MockRoute`s. |
| `MockKit.unregister(method, path)` | Removes a specific route. |
| `MockKit.clearAll()` | Removes all registered routes. |
| `MockKit.routes` | Read-only list of all registered routes. |
| `MockKit.setGlobalDelay(duration)` | Adds latency to **all** mock responses. |
| `MockKit.globalDelay` | Current global delay. |
| `MockKit.enableLogging()` | Turns on verbose console logging. |
| `MockKit.disableLogging()` | Turns off verbose console logging. |
| `MockKit.resolve(method, path, …)` | Low-level resolver; returns `MockResponse?`. |

---

### `MockRoute`

```dart
MockRoute({
  required HttpMethod method,
  required String path,       // supports :param notation
  MockResponse? response,
  MockResponse Function(MockRequest)? responseBuilder,
  String? description,
})
```

---

### `MockResponse`

```dart
MockResponse({
  int statusCode = 200,
  dynamic body,
  Map<String, String> headers,
  Duration delay = Duration.zero,
  bool shouldFail = false,
  String? failureMessage,
})
```

Factory constructors: `ok`, `created`, `badRequest`, `unauthorized`,
`notFound`, `serverError`, `networkFailure`.

---

### `MockRequest`

| Field | Type | Description |
|---|---|---|
| `path` | `String` | Clean request path (no query string). |
| `method` | `HttpMethod` | HTTP method. |
| `queryParameters` | `Map<String, String>` | Parsed query params. |
| `headers` | `Map<String, String>` | Request headers. |
| `body` | `String?` | Raw request body. |
| `pathParameters` | `Map<String, String>` | Extracted `:param` values. |
| `bodyAsJson` | `Map<String, dynamic>` | Body decoded as JSON map. |

---

### `MockDataGenerator`

Static utility — no instantiation required.

| Method | Returns |
|---|---|
| `fromJson(json)` | `MockResponse` wrapping any JSON object. |
| `fromSchema(schema)` | `Map<String, dynamic>` generated from a type-map. |
| `listFromSchema(schema, {count})` | `List<Map<String, dynamic>>`. |
| `paginatedList({schema, page, perPage, total})` | Paginated envelope map. |
| `uuid()` | UUID v4-style string. |
| `name()` | Full name string. |
| `email()` | Email address string. |
| `phone()` | Phone number string. |
| `date()` | ISO-8601 date string. |
| `datetime()` | ISO-8601 datetime string. |
| `url()` | HTTPS URL string. |
| `hexColor()` | Hex color string. |
| `paragraph()` | Short lorem paragraph. |
| `randomInt({min, max})` | Random `int`. |
| `randomDouble({min, max})` | Random `double`. |
| `randomBool()` | Random `bool`. |
| `pickOne(items)` | Random element from `items`. |


---

## Contributing

Contributions, bug reports and feature requests are welcome!

1. Fork the repo.
2. Create a branch: `git checkout -b feat/my-feature`.
3. Commit your changes: `git commit -m 'feat: add my feature'`.
4. Push: `git push origin feat/my-feature`.
5. Open a Pull Request.

Please run `flutter test` and `dart analyze` before submitting a PR.

---

## License

This project is licensed under the [MIT License](LICENSE).
