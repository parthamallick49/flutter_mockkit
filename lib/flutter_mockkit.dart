/// flutter_mockkit — A lightweight dev toolkit for mocking API requests
/// and responses during Flutter development.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_mockkit/flutter_mockkit.dart';
///
/// void main() {
///   // Register a mock
///   MockKit.register(
///     MockRoute(
///       method: HttpMethod.get,
///       path: '/users',
///       response: MockResponse(body: {'users': []}),
///     ),
///   );
///
///   // Enable mock mode
///   MockKit.enable();
///
///   runApp(MyApp());
/// }
/// ```
library flutter_mockkit;

export 'src/mock_registry.dart';
export 'src/mock_http_interceptor.dart';
export 'src/mock_data_generator.dart';
