## 1.0.0

- **Initial release** of `flutter_mockkit`.
- `MockKit` central facade with `enable()` / `disable()` mode toggle and global delay.
- `MockRoute` with static responses and dynamic `responseBuilder` support.
- Named path-parameter matching (`:param` notation).
- `MockResponse` with factory constructors: `ok`, `created`, `badRequest`,
  `unauthorized`, `notFound`, `serverError`, `networkFailure`.
- `MockHttpClient` — drop-in replacement for `http.Client`.
- `MockDioInterceptor` — plug-in interceptor for `Dio`.
- `MockDataGenerator` — schema-driven fake data generation with 13 built-in
  type generators (uuid, name, email, phone, date, url, color, paragraph, …).
- Verbose logging toggle (`MockKit.enableLogging()`).
- 40+ unit tests covering all public APIs.
