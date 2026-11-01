import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One destination in a [SubTabBar].
class SubTab {
  const SubTab({required this.route, required this.label});

  final String route;
  final String label;
}

/// Route-driven secondary navigation for a main tab (Discipleship,
/// Community). The router owns the selection; this only reflects it.
///
/// On a phone the tabs overflow, so the bar fades whichever edge has more
/// tabs behind it, and the selected tab is scrolled into view whenever the
/// route changes — a tab past the screen edge is never silently hidden.
class SubTabBar extends StatefulWidget {
  const SubTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<SubTab> tabs;
  final int selectedIndex;
  final ValueChanged<SubTab> onSelected;

  @override
  State<SubTabBar> createState() => _SubTabBarState();
}

class _SubTabBarState extends State<SubTabBar> with TickerProviderStateMixin {
  late TabController _controller;
  bool _moreLeft = false;
  bool _moreRight = false;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  TabController _createController() => TabController(
        length: widget.tabs.length,
        initialIndex: widget.selectedIndex.clamp(0, widget.tabs.length - 1),
        vsync: this,
      );

  @override
  void didUpdateWidget(SubTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      // A role change can add or remove tabs; a controller can't resize.
      _controller.dispose();
      _controller = _createController();
    } else if (_controller.index != widget.selectedIndex) {
      _controller.animateTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;
    final moreLeft = metrics.extentBefore > 1;
    final moreRight = metrics.extentAfter > 1;
    if (moreLeft != _moreLeft || moreRight != _moreRight) {
      setState(() {
        _moreLeft = moreLeft;
        _moreRight = moreRight;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bar = TabBar(
      controller: _controller,
      isScrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2),
      onTap: (index) => widget.onSelected(widget.tabs[index]),
      tabs: [for (final tab in widget.tabs) Tab(text: tab.label)],
    );

    return Material(
      color: scheme.surface,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _onMetrics(n.metrics),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                _moreLeft ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                _moreRight ? Colors.transparent : Colors.black,
              ],
              stops: const [0, 0.08, 0.92, 1],
            ).createShader(bounds),
            child: bar,
          ),
        ),
      ),
    );
  }
}
