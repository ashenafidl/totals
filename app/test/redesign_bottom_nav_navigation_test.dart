import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totals/_redesign/navigation/navigation_destination.dart';
import 'package:totals/_redesign/widgets/redesign_bottom_nav.dart';
import 'package:totals/providers/theme_provider.dart';

void main() {
  testWidgets('renders 3, 4 and 5 destinations in configured order', (
    tester,
  ) async {
    final layouts = <List<NavigationDestinationId>>[
      const [
        NavigationDestinationId.home,
        NavigationDestinationId.money,
        NavigationDestinationId.you,
      ],
      const [
        NavigationDestinationId.home,
        NavigationDestinationId.shared,
        NavigationDestinationId.budget,
        NavigationDestinationId.you,
      ],
      const [
        NavigationDestinationId.home,
        NavigationDestinationId.shared,
        NavigationDestinationId.money,
        NavigationDestinationId.budget,
        NavigationDestinationId.you,
      ],
    ];

    for (final destinations in layouts) {
      final harnessKey = GlobalKey<_ConfiguredNavigationHarnessState>();
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: _ConfiguredNavigationHarness(
              key: harnessKey,
              destinations: destinations,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labels = destinations
          .map((id) => NavigationDestinations.get(id).label)
          .toList();
      expect(
        labels.map(find.text).every((finder) => finder.evaluate().isNotEmpty),
        isTrue,
      );
      final centers =
          labels.map((label) => tester.getCenter(find.text(label)).dx).toList();
      expect(centers, orderedEquals([...centers]..sort()));

      final target = destinations[1];
      await tester.tap(find.text(NavigationDestinations.get(target).label));
      await tester.pumpAndSettle();
      expect(harnessKey.currentState!.lastTapped, target);
      expect(
        tester
            .getCenter(
              find.byKey(const ValueKey('bottom-nav-selection-indicator')),
            )
            .dx,
        closeTo(
          tester
              .getCenter(find.text(NavigationDestinations.get(target).label))
              .dx,
          0.01,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('long-press hooks stay attached to Money and Shared IDs', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_ConfiguredNavigationHarnessState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: _ConfiguredNavigationHarness(
            key: harnessKey,
            destinations: const [
              NavigationDestinationId.home,
              NavigationDestinationId.shared,
              NavigationDestinationId.money,
              NavigationDestinationId.you,
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Money'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Shared'));
    await tester.pumpAndSettle();
    expect(harnessKey.currentState!.moneyLongPresses, 1);
    expect(harnessKey.currentState!.sharedLongPresses, 1);
  });

  testWidgets(
    'jumps directly to a distant page while the nav indicator animates',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final harnessKey = GlobalKey<_DirectNavigationHarnessState>();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: _DirectNavigationHarness(key: harnessKey),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final indicator = find.byKey(
        const ValueKey('bottom-nav-selection-indicator'),
      );
      final initialIndicatorX = tester.getCenter(indicator).dx;

      await tester.tap(find.text('You'));
      await tester.pump();

      expect(harnessKey.currentState!.page, 4);
      expect(tester.getCenter(indicator).dx, initialIndicatorX);

      await tester.pump(const Duration(milliseconds: 125));
      final movingIndicatorX = tester.getCenter(indicator).dx;
      expect(movingIndicatorX, greaterThan(initialIndicatorX));

      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getCenter(indicator).dx, greaterThan(movingIndicatorX));
      expect(harnessKey.currentState!.page, 4);
    },
  );

  testWidgets(
    'moves the nav indicator continuously with a page swipe',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final harnessKey = GlobalKey<_DirectNavigationHarnessState>();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: _DirectNavigationHarness(key: harnessKey),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final indicator = find.byKey(
        const ValueKey('bottom-nav-selection-indicator'),
      );
      final initialIndicatorX = tester.getCenter(indicator).dx;
      final moneyIndicatorX = tester.getCenter(find.text('Money')).dx;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Page 0')),
      );

      await gesture.moveBy(const Offset(-240, 0));
      await tester.pump();

      final draggedIndicatorX = tester.getCenter(indicator).dx;
      expect(draggedIndicatorX, greaterThan(initialIndicatorX));
      expect(draggedIndicatorX, lessThan(moneyIndicatorX));

      await gesture.moveBy(const Offset(-240, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harnessKey.currentState!.page, 1);
      expect(
        tester.getCenter(indicator).dx,
        closeTo(moneyIndicatorX, 0.01),
      );
    },
  );
}

class _ConfiguredNavigationHarness extends StatefulWidget {
  final List<NavigationDestinationId> destinations;

  const _ConfiguredNavigationHarness({
    super.key,
    required this.destinations,
  });

  @override
  State<_ConfiguredNavigationHarness> createState() =>
      _ConfiguredNavigationHarnessState();
}

class _ConfiguredNavigationHarnessState
    extends State<_ConfiguredNavigationHarness> {
  final PageController _pageController = PageController();
  NavigationDestinationId current = NavigationDestinationId.home;
  NavigationDestinationId? lastTapped;
  int moneyLongPresses = 0;
  int sharedLongPresses = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: List<Widget>.generate(
          widget.destinations.length,
          (index) => Center(child: Text('Destination $index')),
        ),
      ),
      bottomNavigationBar: RedesignBottomNav(
        destinations: widget.destinations,
        currentDestinationId: current,
        pageController: _pageController,
        onTap: (id) {
          final index = widget.destinations.indexOf(id);
          setState(() {
            lastTapped = id;
            current = id;
          });
          _pageController.jumpToPage(index);
        },
        onMoneyLongPress: () => moneyLongPresses++,
        onSharedLongPress: () => sharedLongPresses++,
      ),
    );
  }
}

class _DirectNavigationHarness extends StatefulWidget {
  const _DirectNavigationHarness({super.key});

  @override
  State<_DirectNavigationHarness> createState() =>
      _DirectNavigationHarnessState();
}

class _DirectNavigationHarnessState extends State<_DirectNavigationHarness> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  double? get page => _pageController.page;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(NavigationDestinationId id) {
    final index = const [
      NavigationDestinationId.home,
      NavigationDestinationId.money,
      NavigationDestinationId.budget,
      NavigationDestinationId.shared,
      NavigationDestinationId.you,
    ].indexOf(id);
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: List<Widget>.generate(
          5,
          (index) => Center(child: Text('Page $index')),
        ),
      ),
      bottomNavigationBar: RedesignBottomNav(
        destinations: const [
          NavigationDestinationId.home,
          NavigationDestinationId.money,
          NavigationDestinationId.budget,
          NavigationDestinationId.shared,
          NavigationDestinationId.you,
        ],
        currentDestinationId: const [
          NavigationDestinationId.home,
          NavigationDestinationId.money,
          NavigationDestinationId.budget,
          NavigationDestinationId.shared,
          NavigationDestinationId.you,
        ][_currentIndex],
        pageController: _pageController,
        onTap: _selectPage,
      ),
    );
  }
}
