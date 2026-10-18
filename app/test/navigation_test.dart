import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totals/_redesign/navigation/navigation_destination.dart';
import 'package:totals/services/advanced_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = AdvancedSettingsService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await service.reload();
  });

  test('defaults preserve the five tabs and legacy Tools visibility/order', () {
    final layout = service.navigationLayout.value;
    expect(layout.bottomBar, const [
      NavigationDestinationId.home,
      NavigationDestinationId.money,
      NavigationDestinationId.budget,
      NavigationDestinationId.shared,
      NavigationDestinationId.you,
    ]);
    expect(layout.tools, const [
      NavigationDestinationId.quickAccounts,
      NavigationDestinationId.verifyPayments,
      NavigationDestinationId.loans,
      NavigationDestinationId.failedParsings,
      NavigationDestinationId.webDashboard,
    ]);
    expect(layout.hidden, contains(NavigationDestinationId.dataSync));
    expect(layout.hidden, isNot(contains(NavigationDestinationId.spendingMap)));
  });

  test('all configurable destinations can be moved into the bottom bar',
      () async {
    final allEligible = NavigationDestinations.configurable.every(
      (destination) => destination.eligibleForBottomBar,
    );
    expect(allEligible, isTrue);
    expect(
      NavigationDestinations.configurable.every(
        (destination) => destination.openKind == DestinationOpenKind.page,
      ),
      isTrue,
    );

    await service.setNavigationLayout(
      NavigationLayout(
        middle: const [
          NavigationDestinationId.money,
          NavigationDestinationId.loans,
          NavigationDestinationId.quickAccounts,
        ],
        tools: const [
          NavigationDestinationId.budget,
          NavigationDestinationId.shared,
        ],
        hidden: const {},
      ),
    );
    expect(
      service.navigationLayout.value.middle,
      const [
        NavigationDestinationId.money,
        NavigationDestinationId.loans,
        NavigationDestinationId.quickAccounts,
      ],
    );
  });

  test('migrates the saved legacy Tools set without changing its order',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'advanced_spending_map_enabled': true,
      'redesign_tools_fab_items': <String>[
        'verify_payments',
        'loans',
        'spending_map',
        'unknown_destination',
      ],
    });
    await service.reload();

    expect(service.navigationLayout.value.tools, const [
      NavigationDestinationId.verifyPayments,
      NavigationDestinationId.loans,
      NavigationDestinationId.spendingMap,
    ]);
    expect(
      service.navigationLayout.value.bottomBar,
      containsAll(NavigationLayout.defaultMiddle),
    );
  });

  test('drops invalid ids and pins Home/You while enforcing middle limits',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'redesign_navigation_middle': <String>[
        'home',
        'loans',
        'shared',
        'budget',
        'money',
        'you',
      ],
      'redesign_navigation_tools': <String>[
        'not_a_destination',
        'loans',
        'budget',
      ],
      'redesign_navigation_hidden': <String>[
        'spendingMap',
        'home',
        'money',
        'removed_item',
      ],
    });
    await service.reload();

    final layout = service.navigationLayout.value;
    expect(layout.middle, const [
      NavigationDestinationId.loans,
      NavigationDestinationId.shared,
      NavigationDestinationId.budget,
    ]);
    expect(layout.bottomBar.first, NavigationDestinationId.home);
    expect(layout.bottomBar.last, NavigationDestinationId.you);
    expect(layout.middle.length, NavigationDestinations.maxMiddleSlots);
    expect(layout.tools, isNot(contains(NavigationDestinationId.budget)));
    expect(layout.hidden, isNot(contains(NavigationDestinationId.home)));
    expect(layout.hidden, isNot(contains(NavigationDestinationId.spendingMap)));
    expect(layout.tools, contains(NavigationDestinationId.webDashboard));
  });

  test('uses one middle destination minimum and appends unplaced destinations',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'redesign_navigation_middle': <String>[],
      'redesign_navigation_tools': <String>[],
      'redesign_navigation_hidden': <String>[],
    });
    await service.reload();

    final layout = service.navigationLayout.value;
    expect(
      layout.middle.length,
      greaterThanOrEqualTo(NavigationDestinations.minMiddleSlots),
    );
    expect(layout.middle, contains(NavigationDestinationId.money));
    expect(layout.tools, contains(NavigationDestinationId.dataSync));
    expect(layout.tools, contains(NavigationDestinationId.webDashboard));
  });

  test('Spending Map is always placed in Tools when enabled, never hidden',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'advanced_spending_map_enabled': true,
      'redesign_navigation_middle': <String>['money'],
      'redesign_navigation_tools': <String>[],
      'redesign_navigation_hidden': <String>['spendingMap'],
    });
    await service.reload();

    final layout = service.navigationLayout.value;
    expect(layout.tools, contains(NavigationDestinationId.spendingMap));
    expect(layout.hidden, isNot(contains(NavigationDestinationId.spendingMap)));
  });

  test('persists user ordering and reset restores default layout', () async {
    await service.setNavigationLayout(
      NavigationLayout(
        middle: const [
          NavigationDestinationId.shared,
          NavigationDestinationId.money,
        ],
        tools: const [
          NavigationDestinationId.webDashboard,
          NavigationDestinationId.loans,
        ],
        hidden: const {},
      ),
    );
    expect(
      service.navigationLayout.value.middle,
      const [NavigationDestinationId.shared, NavigationDestinationId.money],
    );
    expect(
      service.navigationLayout.value.tools.take(2),
      const [
        NavigationDestinationId.webDashboard,
        NavigationDestinationId.loans,
      ],
    );

    await service.resetNavigationLayout();
    expect(
      service.navigationLayout.value.bottomBar,
      const [
        NavigationDestinationId.home,
        NavigationDestinationId.money,
        NavigationDestinationId.budget,
        NavigationDestinationId.shared,
        NavigationDestinationId.you,
      ],
    );
  });

  test('keeps the selected destination when available, otherwise falls back',
      () async {
    final updated = NavigationLayout(
      middle: const [NavigationDestinationId.shared],
      tools: const [NavigationDestinationId.budget],
      hidden: const {},
    );

    expect(
      updated.resolveCurrentDestination(NavigationDestinationId.shared),
      NavigationDestinationId.shared,
    );
    expect(
      updated.resolveCurrentDestination(NavigationDestinationId.money),
      NavigationDestinationId.home,
    );
  });
}
