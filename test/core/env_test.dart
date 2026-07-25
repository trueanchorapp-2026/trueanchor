import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/core/config/env.dart';

void main() {
  group('Env', () {
    test('uses the bundled development Supabase defaults when no overrides are provided', () {
      expect(Env.supabaseUrl, isNotEmpty);
      expect(Env.supabasePublishableKey, isNotEmpty);
      expect(Env.supabaseUrl, contains('supabase.co'));
      expect(Env.supabasePublishableKey, startsWith('sb_publishable_'));
    });
  });
}
