import 'package:flutter/material.dart';
import 'package:totals/_redesign/theme/app_icons.dart';
import 'package:totals/l10n/app_localizations.dart';

enum NavigationDestinationId {
  home,
  money,
  budget,
  shared,
  quickAccounts,
  verifyPayments,
  loans,
  spendingMap,
  failedParsings,
  dataSync,
  webDashboard,
  you,
}

enum DestinationLongPress { quickCash, quickAccessAccounts, profileMenu }

enum DestinationOpenKind { page, route }

class NavigationDestination {
  final NavigationDestinationId id;
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool eligibleForBottomBar;
  final DestinationOpenKind openKind;
  final DestinationLongPress? longPress;

  const NavigationDestination({
    required this.id,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.eligibleForBottomBar,
    required this.openKind,
    this.longPress,
  });

  String localizedLabel(BuildContext context) => context.l10nText(label);
}

abstract final class NavigationDestinations {
  static const int minMiddleSlots = 1;
  static const int maxMiddleSlots = 3;

  static const List<NavigationDestination> configurable = [
    NavigationDestination(
      id: NavigationDestinationId.money,
      label: 'Money',
      activeIcon: AppIcons.account_balance_wallet,
      inactiveIcon: AppIcons.account_balance_wallet_outlined,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
      longPress: DestinationLongPress.quickCash,
    ),
    NavigationDestination(
      id: NavigationDestinationId.budget,
      label: 'Budget',
      activeIcon: AppIcons.savings,
      inactiveIcon: AppIcons.savings_outlined,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
    NavigationDestination(
      id: NavigationDestinationId.shared,
      label: 'Shared',
      activeIcon: AppIcons.group,
      inactiveIcon: AppIcons.group_outlined,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
      longPress: DestinationLongPress.quickAccessAccounts,
    ),
    NavigationDestination(
      id: NavigationDestinationId.quickAccounts,
      label: 'Quick Accounts',
      activeIcon: AppIcons.account_balance_outlined,
      inactiveIcon: AppIcons.account_balance_outlined,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
    NavigationDestination(
      id: NavigationDestinationId.verifyPayments,
      label: 'Verify Payments',
      activeIcon: AppIcons.qr_code_scanner_rounded,
      inactiveIcon: AppIcons.qr_code_scanner_rounded,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
    NavigationDestination(
      id: NavigationDestinationId.loans,
      label: 'Loans',
      activeIcon: AppIcons.debts,
      inactiveIcon: AppIcons.debts,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
    NavigationDestination(
      id: NavigationDestinationId.spendingMap,
      label: 'Spending Map',
      activeIcon: AppIcons.map_rounded,
      inactiveIcon: AppIcons.map_rounded,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
    NavigationDestination(
      id: NavigationDestinationId.failedParsings,
      label: 'Failed Parsings',
      activeIcon: AppIcons.sms_outlined,
      inactiveIcon: AppIcons.sms_outlined,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
    NavigationDestination(
      id: NavigationDestinationId.dataSync,
      label: 'Data Sync',
      activeIcon: AppIcons.cloud_download,
      inactiveIcon: AppIcons.cloud_download,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
    NavigationDestination(
      id: NavigationDestinationId.webDashboard,
      label: 'Web Dashboard',
      activeIcon: AppIcons.dashboard_outlined,
      inactiveIcon: AppIcons.dashboard_outlined,
      eligibleForBottomBar: true,
      openKind: DestinationOpenKind.page,
    ),
  ];

  static const home = NavigationDestination(
    id: NavigationDestinationId.home,
    label: 'Home',
    activeIcon: AppIcons.home_filled,
    inactiveIcon: AppIcons.home_outlined,
    eligibleForBottomBar: true,
    openKind: DestinationOpenKind.page,
  );

  static const you = NavigationDestination(
    id: NavigationDestinationId.you,
    label: 'You',
    activeIcon: AppIcons.person,
    inactiveIcon: AppIcons.person_outline,
    eligibleForBottomBar: true,
    openKind: DestinationOpenKind.page,
    longPress: DestinationLongPress.profileMenu,
  );

  static final Map<NavigationDestinationId, NavigationDestination> byId = {
    NavigationDestinationId.home: home,
    for (final destination in configurable) destination.id: destination,
    NavigationDestinationId.you: you,
  };

  static NavigationDestination get(NavigationDestinationId id) => byId[id]!;

  static NavigationDestinationId? fromStorage(String value) {
    for (final id in NavigationDestinationId.values) {
      if (id.name == value) return id;
    }
    return null;
  }
}

@immutable
class NavigationLayout {
  final List<NavigationDestinationId> middle;
  final List<NavigationDestinationId> tools;
  final Set<NavigationDestinationId> hidden;

  NavigationLayout({
    required List<NavigationDestinationId> middle,
    required List<NavigationDestinationId> tools,
    required Set<NavigationDestinationId> hidden,
  })  : middle = List.unmodifiable(middle),
        tools = List.unmodifiable(tools),
        hidden = Set.unmodifiable(hidden);

  List<NavigationDestinationId> get bottomBar => [
        NavigationDestinationId.home,
        ...middle,
        NavigationDestinationId.you,
      ];

  List<NavigationDestinationId> get completeBottomBar => bottomBar;

  NavigationDestinationId resolveCurrentDestination(
    NavigationDestinationId current,
  ) =>
      bottomBar.contains(current) ? current : NavigationDestinationId.home;

  static const defaultMiddle = [
    NavigationDestinationId.money,
    NavigationDestinationId.budget,
    NavigationDestinationId.shared,
  ];
}
