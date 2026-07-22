import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialised Supabase client. Infrastructure repositories depend on this
/// rather than reaching for the `Supabase.instance` singleton directly, so
/// tests can override it with a fake.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Auth state as a stream. `go_router` listens to this to re-run its redirect
/// ladder the moment a session appears or disappears.
final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// The current session, or null when signed out.
///
/// Reads through the auth stream so it stays live, but falls back to the
/// client's cached session for the very first synchronous read on startup
/// (session restoration from local storage completes before runApp).
final currentSessionProvider = Provider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final event = ref.watch(authStateChangesProvider);
  return event.value?.session ?? client.auth.currentSession;
});

final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider)?.user.id,
);
