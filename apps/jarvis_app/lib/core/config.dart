/// API base URL for local development.
///
/// - Windows / macOS / iOS simulator: http://127.0.0.1:8000
/// - Android emulator: http://10.0.2.2:8000
/// - Physical device: http://YOUR_LAN_IP:8000
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);
