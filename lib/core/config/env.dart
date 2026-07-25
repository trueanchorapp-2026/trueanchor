/// Compile-time configuration, supplied via `--dart-define`.
///
/// Nothing here is secret: the publishable key is designed for client-side use
/// and Postgres RLS is what actually protects the data. Keeping it out of the
/// source tree still buys us rotation without a code change.
abstract final class Env {
  static const String _defaultSupabaseUrl =
      'https://vilevuoyzfkzcybgoixd.supabase.co';
  static const String _defaultPublishableKey =
      'sb_publishable_UcpyijWXcIs0tMOofu_UzA_2JRXZqU-';

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultSupabaseUrl);

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: _defaultPublishableKey,
  );

  /// Fails fast at startup rather than surfacing as an opaque 401 on the first
  /// query, which is a much harder thing to diagnose.
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration.\n'
        'Run with:\n'
        '  flutter run -d chrome \\\n'
        '    --dart-define=SUPABASE_URL=... \\\n'
        '    --dart-define=SUPABASE_PUBLISHABLE_KEY=...\n'
        'Or use scripts/run_web.ps1.',
      );
    }
  }
}
