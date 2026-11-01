import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/core/theme/app_theme.dart';
import 'package:trueanchor/core/widgets/sub_tab_bar.dart';

const _tabs = [
  SubTab(route: '/a', label: 'Alpha'),
  SubTab(route: '/b', label: 'Bravo'),
  SubTab(route: '/c', label: 'Charlie'),
];

Widget _host({
  required int selected,
  required ValueChanged<SubTab> onSelected,
  List<SubTab> tabs = _tabs,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SubTabBar(
        tabs: tabs,
        selectedIndex: selected,
        onSelected: onSelected,
      ),
    ),
  );
}

TabController _controller(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!;

void main() {
  testWidgets('tapping a tab reports its route', (tester) async {
    SubTab? tapped;
    await tester.pumpWidget(_host(selected: 0, onSelected: (t) => tapped = t));

    await tester.tap(find.text('Charlie'));
    await tester.pumpAndSettle();

    expect(tapped?.route, '/c');
  });

  testWidgets('selection follows the route', (tester) async {
    await tester.pumpWidget(_host(selected: 0, onSelected: (_) {}));
    expect(_controller(tester).index, 0);

    await tester.pumpWidget(_host(selected: 2, onSelected: (_) {}));
    await tester.pumpAndSettle();
    expect(_controller(tester).index, 2);
  });

  testWidgets('survives the tab list changing length', (tester) async {
    await tester.pumpWidget(_host(selected: 1, onSelected: (_) {}));

    await tester.pumpWidget(
      _host(selected: 0, onSelected: (_) {}, tabs: _tabs.take(2).toList()),
    );
    await tester.pumpAndSettle();

    expect(_controller(tester).length, 2);
    expect(_controller(tester).index, 0);
    expect(tester.takeException(), isNull);
  });
}
