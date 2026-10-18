import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totals/_redesign/navigation/navigation_destination.dart';

enum ProfileDoubleTapAction {
  lock,
  doNothing,
}

enum ToolsFabItem {
  quickAccounts,
  verifyPayments,
  loans,
  spendingMap,
  failedParsings,
  dataSync,
  webDashboard,
}

class AdvancedSettingsService {
  AdvancedSettingsService._();

  static final AdvancedSettingsService instance = AdvancedSettingsService._();

  static const String _profileDoubleTapActionKey =
      'redesign_profile_double_tap_action';
  static const String _toolsFabItemsKey = 'redesign_tools_fab_items';
  static const String _navigationMiddleKey = 'redesign_navigation_middle';
  static const String _navigationToolsKey = 'redesign_navigation_tools';
  static const String _navigationHiddenKey = 'redesign_navigation_hidden';
  static const String _telegramBackupEnabledKey =
      'advanced_telegram_backup_enabled';
  static const String _telegramBackupConsentVersionKey =
      'advanced_telegram_backup_consent_version';
  static const String _spendingMapEnabledKey = 'advanced_spending_map_enabled';
  static const int currentTelegramBackupConsentVersion = 2;
  static const Set<ToolsFabItem> defaultToolsFabItems = {
    ToolsFabItem.quickAccounts,
    ToolsFabItem.verifyPayments,
    ToolsFabItem.loans,
    ToolsFabItem.failedParsings,
    ToolsFabItem.webDashboard,
  };

  final ValueNotifier<ProfileDoubleTapAction> profileDoubleTapAction =
      ValueNotifier<ProfileDoubleTapAction>(ProfileDoubleTapAction.lock);
  final ValueNotifier<Set<ToolsFabItem>> toolsFabItems =
      ValueNotifier<Set<ToolsFabItem>>(defaultToolsFabItems);
  final ValueNotifier<NavigationLayout> navigationLayout =
      ValueNotifier<NavigationLayout>(
    NavigationLayout(
      middle: NavigationLayout.defaultMiddle,
      tools: _defaultToolDestinations,
      hidden: const {},
    ),
  );
  final ValueNotifier<bool> telegramBackupEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<int> telegramBackupConsentVersion = ValueNotifier<int>(0);
  final ValueNotifier<bool> spendingMapEnabled = ValueNotifier<bool>(false);

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await reload();
  }

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_profileDoubleTapActionKey);
    profileDoubleTapAction.value = _fromStorage(raw);
    spendingMapEnabled.value = prefs.getBool(_spendingMapEnabledKey) ?? false;
    final savedTools = _toolsFabItemsFromStorage(
      prefs.getStringList(_toolsFabItemsKey),
      spendingMapEnabled: spendingMapEnabled.value,
    );
    final hasNavigationLayout = prefs.containsKey(_navigationMiddleKey);
    navigationLayout.value = _navigationLayoutFromStorage(
      middle: prefs.getStringList(_navigationMiddleKey),
      tools: prefs.getStringList(_navigationToolsKey),
      hidden: prefs.getStringList(_navigationHiddenKey),
      legacyTools: savedTools,
      spendingMapEnabled: spendingMapEnabled.value,
      hasNavigationLayout: hasNavigationLayout,
    );
    toolsFabItems.value = _legacyToolsFromLayout(navigationLayout.value);
    telegramBackupConsentVersion.value =
        prefs.getInt(_telegramBackupConsentVersionKey) ?? 0;
    final storedTelegramBackupEnabled =
        prefs.getBool(_telegramBackupEnabledKey) ?? false;
    final consentIsCurrent = telegramBackupConsentVersion.value >=
        currentTelegramBackupConsentVersion;
    telegramBackupEnabled.value =
        storedTelegramBackupEnabled && consentIsCurrent;
    if (storedTelegramBackupEnabled && !consentIsCurrent) {
      await prefs.setBool(_telegramBackupEnabledKey, false);
    }
    _loaded = true;
  }

  Future<void> setProfileDoubleTapAction(ProfileDoubleTapAction action) async {
    await ensureLoaded();
    if (profileDoubleTapAction.value == action) return;
    profileDoubleTapAction.value = action;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileDoubleTapActionKey, _toStorage(action));
  }

  Future<void> setToolsFabItems(Set<ToolsFabItem> items) async {
    await ensureLoaded();
    final normalized = _normalizeToolsFabItems(
      items,
      spendingMapEnabled: spendingMapEnabled.value,
    );
    final selectedIds = normalized.map(_destinationForToolsFabItem).toSet();
    final current = navigationLayout.value;
    final middle = current.middle;
    final hidden = <NavigationDestinationId>{
      ...current.hidden,
      for (final destination in NavigationDestinations.configurable)
        if (_toolsFabItemForDestination(destination.id) != null &&
            !selectedIds.contains(destination.id) &&
            destination.id != NavigationDestinationId.spendingMap)
          destination.id,
    };
    for (final id in selectedIds) {
      hidden.remove(id);
    }
    final tools = <NavigationDestinationId>[
      for (final id in current.tools)
        if (selectedIds.contains(id)) id,
      for (final id
          in NavigationDestinations.configurable.map((item) => item.id))
        if (selectedIds.contains(id) && !current.tools.contains(id)) id,
    ];
    await setNavigationLayout(
      NavigationLayout(middle: middle, tools: tools, hidden: hidden),
    );
  }

  Future<void> setNavigationLayout(NavigationLayout layout) async {
    await ensureLoaded();
    final normalized = _normalizeNavigationLayout(
      layout,
      spendingMapEnabled: spendingMapEnabled.value,
    );
    if (normalized.middle.length < NavigationDestinations.minMiddleSlots ||
        normalized.middle.length > NavigationDestinations.maxMiddleSlots) {
      throw StateError('Bottom bar must contain between one and '
          '${NavigationDestinations.maxMiddleSlots} middle destination(s).');
    }
    final prefs = await SharedPreferences.getInstance();
    await _saveNavigationLayout(prefs, normalized);
    final legacyTools = _legacyToolsFromLayout(normalized);
    await prefs.setStringList(
      _toolsFabItemsKey,
      legacyTools.map(_toolsFabItemToStorage).toList(growable: false),
    );
    navigationLayout.value = normalized;
    toolsFabItems.value = legacyTools;
  }

  Future<void> resetNavigationLayout() async {
    await ensureLoaded();
    final defaultTools = <NavigationDestinationId>[
      for (final item in ToolsFabItem.values)
        if (_defaultToolsFabItems(spendingMapEnabled.value).contains(item))
          _destinationForToolsFabItem(item),
    ];
    await setNavigationLayout(
      NavigationLayout(
        middle: NavigationLayout.defaultMiddle,
        tools: defaultTools,
        hidden: {
          for (final destination in NavigationDestinations.configurable)
            if (_isHiddenInLegacyToolsLayout(
              destination.id,
              _defaultToolsFabItems(spendingMapEnabled.value),
            ))
              destination.id,
        },
      ),
    );
  }

  Future<void> setSpendingMapEnabled(bool enabled) async {
    await ensureLoaded();
    if (spendingMapEnabled.value == enabled) return;

    final prefs = await SharedPreferences.getInstance();

    final current = navigationLayout.value;
    final tools = [...current.tools];
    if (enabled && !tools.contains(NavigationDestinationId.spendingMap)) {
      tools.add(NavigationDestinationId.spendingMap);
    } else if (!enabled) {
      tools.remove(NavigationDestinationId.spendingMap);
    }
    final normalized = _normalizeNavigationLayout(
      NavigationLayout(
        middle: current.middle,
        tools: tools,
        hidden: current.hidden,
      ),
      spendingMapEnabled: enabled,
    );
    await prefs.setBool(_spendingMapEnabledKey, enabled);
    await _saveNavigationLayout(prefs, normalized);
    final legacyTools = _legacyToolsFromLayout(normalized);
    await prefs.setStringList(
      _toolsFabItemsKey,
      legacyTools.map(_toolsFabItemToStorage).toList(growable: false),
    );
    spendingMapEnabled.value = enabled;
    navigationLayout.value = normalized;
    toolsFabItems.value = legacyTools;
  }

  List<ToolsFabItem> get availableToolsFabItems => ToolsFabItem.values
      .where(
        (item) => item != ToolsFabItem.spendingMap || spendingMapEnabled.value,
      )
      .toList(growable: false);

  static const List<NavigationDestinationId> _defaultToolDestinations = [
    NavigationDestinationId.quickAccounts,
    NavigationDestinationId.verifyPayments,
    NavigationDestinationId.loans,
    NavigationDestinationId.failedParsings,
    NavigationDestinationId.webDashboard,
  ];

  static Set<ToolsFabItem> _defaultToolsFabItems(bool spendingMapEnabled) => {
        ...defaultToolsFabItems,
        if (spendingMapEnabled) ToolsFabItem.spendingMap,
      };

  Future<void> setTelegramBackupEnabled(bool enabled) async {
    await ensureLoaded();
    if (telegramBackupEnabled.value == enabled) return;
    if (enabled && !hasTelegramBackupConsent) {
      throw StateError(
        'Telegram Backup cannot be enabled before consent is recorded.',
      );
    }
    telegramBackupEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_telegramBackupEnabledKey, enabled);
  }

  bool get hasTelegramBackupConsent =>
      telegramBackupConsentVersion.value >= currentTelegramBackupConsentVersion;

  Future<void> recordTelegramBackupConsent() async {
    await ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _telegramBackupConsentVersionKey,
      currentTelegramBackupConsentVersion,
    );
    telegramBackupConsentVersion.value = currentTelegramBackupConsentVersion;
  }

  static NavigationLayout _navigationLayoutFromStorage({
    required List<String>? middle,
    required List<String>? tools,
    required List<String>? hidden,
    required Set<ToolsFabItem> legacyTools,
    required bool spendingMapEnabled,
    required bool hasNavigationLayout,
  }) {
    if (!hasNavigationLayout) {
      return _normalizeNavigationLayout(
        NavigationLayout(
          middle: NavigationLayout.defaultMiddle,
          tools: [
            for (final item in ToolsFabItem.values)
              if (legacyTools.contains(item) &&
                  (item != ToolsFabItem.spendingMap || spendingMapEnabled))
                _destinationForToolsFabItem(item),
          ],
          hidden: {
            for (final destination in NavigationDestinations.configurable)
              if (_isHiddenInLegacyToolsLayout(destination.id, legacyTools))
                destination.id,
          },
        ),
        spendingMapEnabled: spendingMapEnabled,
      );
    }

    final selectedMiddle = _parseDestinationIds(middle);
    final selectedTools = _parseDestinationIds(tools);
    final selectedHidden = _parseDestinationIds(hidden).toSet();
    return _normalizeNavigationLayout(
      NavigationLayout(
        middle: selectedMiddle.isEmpty
            ? NavigationLayout.defaultMiddle
            : selectedMiddle,
        tools: selectedTools,
        hidden: selectedHidden,
      ),
      spendingMapEnabled: spendingMapEnabled,
    );
  }

  static List<NavigationDestinationId> _parseDestinationIds(
    List<String>? values,
  ) {
    final result = <NavigationDestinationId>[];
    for (final value in values ?? const <String>[]) {
      final id = NavigationDestinations.fromStorage(value);
      if (id != null && !result.contains(id)) result.add(id);
    }
    return result;
  }

  static bool _isHiddenInLegacyToolsLayout(
    NavigationDestinationId id,
    Set<ToolsFabItem> visible,
  ) {
    final legacyItem = _toolsFabItemForDestination(id);
    return id != NavigationDestinationId.spendingMap &&
        legacyItem != null &&
        !visible.contains(legacyItem);
  }

  static NavigationLayout _normalizeNavigationLayout(
    NavigationLayout layout, {
    required bool spendingMapEnabled,
  }) {
    final middle = <NavigationDestinationId>[];
    for (final id in layout.middle) {
      final destination = NavigationDestinations.byId[id];
      if (destination == null ||
          !NavigationDestinations.configurable.any((item) => item.id == id) ||
          !destination.eligibleForBottomBar ||
          middle.contains(id) ||
          middle.length >= NavigationDestinations.maxMiddleSlots) {
        continue;
      }
      middle.add(id);
    }
    while (middle.length < NavigationDestinations.minMiddleSlots) {
      final fallback = NavigationLayout.defaultMiddle.firstWhere(
        (id) => !middle.contains(id),
        orElse: () => NavigationDestinationId.money,
      );
      middle.add(fallback);
    }

    final hidden = <NavigationDestinationId>{};
    for (final id in layout.hidden) {
      final destination = NavigationDestinations.byId[id];
      if (destination != null &&
          NavigationDestinations.configurable.any((item) => item.id == id) &&
          id != NavigationDestinationId.spendingMap &&
          !middle.contains(id)) {
        hidden.add(id);
      }
    }

    final tools = <NavigationDestinationId>[];
    for (final id in layout.tools) {
      final destination = NavigationDestinations.byId[id];
      if (destination == null ||
          !NavigationDestinations.configurable.any((item) => item.id == id) ||
          middle.contains(id) ||
          hidden.contains(id) ||
          tools.contains(id) ||
          (id == NavigationDestinationId.spendingMap && !spendingMapEnabled)) {
        continue;
      }
      tools.add(id);
    }
    if (spendingMapEnabled &&
        !middle.contains(NavigationDestinationId.spendingMap) &&
        !hidden.contains(NavigationDestinationId.spendingMap) &&
        !tools.contains(NavigationDestinationId.spendingMap)) {
      tools.add(NavigationDestinationId.spendingMap);
    }
    for (final destination in NavigationDestinations.configurable) {
      final id = destination.id;
      if (middle.contains(id) ||
          hidden.contains(id) ||
          tools.contains(id) ||
          (id == NavigationDestinationId.spendingMap && !spendingMapEnabled)) {
        continue;
      }
      tools.add(id);
    }
    return NavigationLayout(middle: middle, tools: tools, hidden: hidden);
  }

  static Future<void> _saveNavigationLayout(
    SharedPreferences prefs,
    NavigationLayout layout,
  ) async {
    await prefs.setStringList(
      _navigationMiddleKey,
      layout.middle.map((id) => id.name).toList(growable: false),
    );
    await prefs.setStringList(
      _navigationToolsKey,
      layout.tools.map((id) => id.name).toList(growable: false),
    );
    await prefs.setStringList(
      _navigationHiddenKey,
      layout.hidden.map((id) => id.name).toList(growable: false),
    );
  }

  static Set<ToolsFabItem> _legacyToolsFromLayout(NavigationLayout layout) {
    return Set.unmodifiable({
      for (final id in layout.tools)
        if (_toolsFabItemForDestination(id) case final item?) item,
    });
  }

  static NavigationDestinationId _destinationForToolsFabItem(
    ToolsFabItem item,
  ) {
    switch (item) {
      case ToolsFabItem.quickAccounts:
        return NavigationDestinationId.quickAccounts;
      case ToolsFabItem.verifyPayments:
        return NavigationDestinationId.verifyPayments;
      case ToolsFabItem.loans:
        return NavigationDestinationId.loans;
      case ToolsFabItem.spendingMap:
        return NavigationDestinationId.spendingMap;
      case ToolsFabItem.failedParsings:
        return NavigationDestinationId.failedParsings;
      case ToolsFabItem.dataSync:
        return NavigationDestinationId.dataSync;
      case ToolsFabItem.webDashboard:
        return NavigationDestinationId.webDashboard;
    }
  }

  static ToolsFabItem? _toolsFabItemForDestination(
    NavigationDestinationId id,
  ) {
    switch (id) {
      case NavigationDestinationId.quickAccounts:
        return ToolsFabItem.quickAccounts;
      case NavigationDestinationId.verifyPayments:
        return ToolsFabItem.verifyPayments;
      case NavigationDestinationId.loans:
        return ToolsFabItem.loans;
      case NavigationDestinationId.spendingMap:
        return ToolsFabItem.spendingMap;
      case NavigationDestinationId.failedParsings:
        return ToolsFabItem.failedParsings;
      case NavigationDestinationId.dataSync:
        return ToolsFabItem.dataSync;
      case NavigationDestinationId.webDashboard:
        return ToolsFabItem.webDashboard;
      case NavigationDestinationId.home:
      case NavigationDestinationId.money:
      case NavigationDestinationId.budget:
      case NavigationDestinationId.shared:
      case NavigationDestinationId.you:
        return null;
    }
  }

  static ProfileDoubleTapAction _fromStorage(String? raw) {
    switch (raw) {
      case 'do_nothing':
        return ProfileDoubleTapAction.doNothing;
      case 'lock':
      default:
        return ProfileDoubleTapAction.lock;
    }
  }

  static String _toStorage(ProfileDoubleTapAction action) {
    switch (action) {
      case ProfileDoubleTapAction.lock:
        return 'lock';
      case ProfileDoubleTapAction.doNothing:
        return 'do_nothing';
    }
  }

  static Set<ToolsFabItem> _toolsFabItemsFromStorage(
    List<String>? raw, {
    required bool spendingMapEnabled,
  }) {
    if (raw == null || raw.isEmpty) {
      return _normalizeToolsFabItems(
        defaultToolsFabItems,
        spendingMapEnabled: spendingMapEnabled,
      );
    }
    return _normalizeToolsFabItems(
      raw.map(_toolsFabItemFromStorage).whereType<ToolsFabItem>().toSet(),
      spendingMapEnabled: spendingMapEnabled,
    );
  }

  static Set<ToolsFabItem> _normalizeToolsFabItems(
    Set<ToolsFabItem> items, {
    required bool spendingMapEnabled,
  }) {
    final requested = Set<ToolsFabItem>.of(
      items.isEmpty ? defaultToolsFabItems : items,
    );
    if (spendingMapEnabled) {
      requested.add(ToolsFabItem.spendingMap);
    } else {
      requested.remove(ToolsFabItem.spendingMap);
    }
    final ordered = <ToolsFabItem>{};
    for (final item in ToolsFabItem.values) {
      if (requested.contains(item)) ordered.add(item);
    }
    return Set.unmodifiable(ordered.isEmpty ? defaultToolsFabItems : ordered);
  }

  static ToolsFabItem? _toolsFabItemFromStorage(String raw) {
    switch (raw) {
      case 'quick_accounts':
        return ToolsFabItem.quickAccounts;
      case 'verify_payments':
        return ToolsFabItem.verifyPayments;
      case 'loans':
        return ToolsFabItem.loans;
      case 'spending_map':
        return ToolsFabItem.spendingMap;
      case 'failed_parsings':
        return ToolsFabItem.failedParsings;
      case 'data_sync':
        return ToolsFabItem.dataSync;
      case 'web_dashboard':
        return ToolsFabItem.webDashboard;
    }
    return null;
  }

  static String _toolsFabItemToStorage(ToolsFabItem item) {
    switch (item) {
      case ToolsFabItem.quickAccounts:
        return 'quick_accounts';
      case ToolsFabItem.verifyPayments:
        return 'verify_payments';
      case ToolsFabItem.loans:
        return 'loans';
      case ToolsFabItem.spendingMap:
        return 'spending_map';
      case ToolsFabItem.failedParsings:
        return 'failed_parsings';
      case ToolsFabItem.dataSync:
        return 'data_sync';
      case ToolsFabItem.webDashboard:
        return 'web_dashboard';
    }
  }
}
