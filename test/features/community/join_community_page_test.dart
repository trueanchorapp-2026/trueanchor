import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/core/theme/app_theme.dart';
import 'package:trueanchor/features/community/application/community_providers.dart';
import 'package:trueanchor/features/community/domain/community.dart';
import 'package:trueanchor/features/community/domain/community_repository.dart';
import 'package:trueanchor/features/community/domain/region.dart';
import 'package:trueanchor/features/community/presentation/join_community_page.dart';

/// Only the two reads the picker makes; everything else throws so an
/// accidental call is loud rather than silently empty.
class _FakeCommunityRepository implements CommunityRepository {
  @override
  Future<List<Region>> fetchRegions() async => [
    Region(id: 'r1', name: 'Broward County', createdAt: DateTime(2026)),
  ];

  @override
  Future<List<Community>> fetchCommunities({String? regionId}) async => [
    Community(
      id: 'c1',
      regionId: 'r1',
      name: 'Coral Springs',
      city: 'Coral Springs',
      state: 'FL',
      createdAt: DateTime(2026),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  // The app theme is what makes this a regression test: its
  // FilledButtonThemeData sets an infinite minimum width, which a ListTile's
  // trailing slot resolves to the full tile and then asserts on. Pumping the
  // page under a default theme hides the bug entirely.
  Widget pageUnderTest() => ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      communityRepositoryProvider.overrideWithValue(_FakeCommunityRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: JoinCommunityPage()),
    ),
  );

  testWidgets('selecting a region lists that region\'s communities', (
    tester,
  ) async {
    await tester.pumpWidget(pageUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select your region'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Broward County').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Coral Springs'), findsWidgets);
    expect(find.text('Join'), findsOneWidget);
  });

  testWidgets('the Join button sizes to its label, not the tile', (
    tester,
  ) async {
    await tester.pumpWidget(pageUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select your region'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Broward County').last);
    await tester.pumpAndSettle();

    final button = tester.getSize(find.widgetWithText(FilledButton, 'Join'));
    final tile = tester.getSize(find.byType(ListTile));
    expect(button.width, lessThan(tile.width / 2));
  });
}
