import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/error/app_exception.dart';
import 'package:trueanchor/features/auth/application/auth_providers.dart';
import 'package:trueanchor/features/auth/domain/auth_repository.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  ProviderContainer container() => ProviderContainer.test(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );

  group('signIn', () {
    test('reports success and settles to data', () async {
      when(() => repository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {});

      final c = container();
      final ok = await c
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.com', password: 'secret');

      expect(ok, isTrue);
      expect(c.read(authControllerProvider).hasError, isFalse);
      expect(c.read(authControllerProvider).isLoading, isFalse);
    });

    test('reports failure and keeps the error for the page to show', () async {
      when(() => repository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AppException('That email or password is incorrect.'));

      final c = container();
      final ok = await c
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.com', password: 'wrong');

      // A failed sign-in must never read as success — the router would send an
      // unauthenticated user into the app shell.
      expect(ok, isFalse);
      final state = c.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<AppException>());
    });
  });

  group('signUp', () {
    test('forwards every field the signup trigger needs', () async {
      when(() => repository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            inviteCode: any(named: 'inviteCode'),
          )).thenAnswer((_) async {});

      final ok = await container().read(authControllerProvider.notifier).signUp(
            email: 'ella@example.com',
            password: 'secret123',
            firstName: 'Ella',
            lastName: 'Nguyen',
            inviteCode: 'TAYOUTH',
          );

      expect(ok, isTrue);
      verify(() => repository.signUp(
            email: 'ella@example.com',
            password: 'secret123',
            firstName: 'Ella',
            lastName: 'Nguyen',
            inviteCode: 'TAYOUTH',
          )).called(1);
    });

    test('a rejected invite code fails the signup', () async {
      when(() => repository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            inviteCode: any(named: 'inviteCode'),
          )).thenThrow(const AppException('That church code is not valid.'));

      final ok = await container().read(authControllerProvider.notifier).signUp(
            email: 'ella@example.com',
            password: 'secret123',
            firstName: 'Ella',
            lastName: 'Nguyen',
            inviteCode: 'NOPE',
          );

      expect(ok, isFalse);
    });
  });

  group('invitePreviewProvider', () {
    test('exposes the church and role a code resolves to', () async {
      when(() => repository.validateInviteCode('TAPARENT')).thenAnswer(
        (_) async => const InvitePreview(
          churchId: 'church-1',
          churchName: 'CBCCS',
          role: UserRole.parent,
        ),
      );

      final preview = await container()
          .read(invitePreviewProvider('TAPARENT').future);

      expect(preview, isNotNull);
      expect(preview!.churchName, 'CBCCS');
      expect(preview.role, UserRole.parent);
    });

    test('an unknown code resolves to null, not an error', () async {
      when(() => repository.validateInviteCode('NOPE'))
          .thenAnswer((_) async => null);

      expect(
        await container().read(invitePreviewProvider('NOPE').future),
        isNull,
      );
    });
  });
}
