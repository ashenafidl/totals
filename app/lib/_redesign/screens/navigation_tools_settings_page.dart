import 'package:flutter/material.dart' hide NavigationDestination;
import 'package:totals/_redesign/navigation/navigation_destination.dart';
import 'package:totals/_redesign/theme/app_colors.dart';
import 'package:totals/_redesign/theme/app_icons.dart';
import 'package:totals/l10n/app_localizations.dart';
import 'package:totals/services/advanced_settings_service.dart';

class NavigationToolsSettingsPage extends StatefulWidget {
  const NavigationToolsSettingsPage({super.key});

  @override
  State<NavigationToolsSettingsPage> createState() =>
      _NavigationToolsSettingsPageState();
}

class _NavigationToolsSettingsPageState
    extends State<NavigationToolsSettingsPage> {
  late List<NavigationDestinationId> _middle;
  late List<NavigationDestinationId> _tools;
  late Set<NavigationDestinationId> _hidden;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  void _loadLayout() {
    final layout = AdvancedSettingsService.instance.navigationLayout.value;
    _middle = [...layout.middle];
    _tools = [...layout.tools];
    _hidden = {...layout.hidden};
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      await AdvancedSettingsService.instance.setNavigationLayout(
        NavigationLayout(middle: _middle, tools: _tools, hidden: _hidden),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.l10nText('Could not save navigation settings.')}: $error',
          ),
        ),
      );
      _loadLayout();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  _Placement? _placementOf(NavigationDestinationId id) {
    if (_middle.contains(id)) return _Placement.bottomBar;
    if (_tools.contains(id)) return _Placement.tools;
    if (_hidden.contains(id)) return _Placement.hidden;
    return null;
  }

  bool _canDrop(NavigationDestinationId id, _Placement placement) {
    if (_saving) return false;
    final source = _placementOf(id);
    if (source == _Placement.bottomBar &&
        placement != _Placement.bottomBar &&
        _middle.length <= NavigationDestinations.minMiddleSlots) {
      return false;
    }
    if (placement == _Placement.bottomBar) {
      return NavigationDestinations.get(id).eligibleForBottomBar;
    }
    if (placement == _Placement.hidden) {
      return id != NavigationDestinationId.spendingMap &&
          (_placementOf(id) != _Placement.bottomBar ||
              _middle.length > NavigationDestinations.minMiddleSlots);
    }
    return true;
  }

  Future<void> _dropOn(
    NavigationDestinationId id,
    _Placement target, {
    int? index,
  }) async {
    final source = _placementOf(id);
    if (source == null) return;
    if (source == target) {
      if (target == _Placement.hidden) return;
      final items = _itemsFor(target);
      final oldIndex = items.indexOf(id);
      if (oldIndex < 0) return;
      final newIndex = (index ?? items.length).clamp(0, items.length).toInt();
      if (oldIndex == newIndex || oldIndex + 1 == newIndex) return;
      setState(() {
        items.removeAt(oldIndex);
        items.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, id);
      });
      await _persist();
      return;
    }
    if (!_canDrop(id, target)) {
      _showBlockedMove();
      return;
    }
    setState(() {
      _middle.remove(id);
      _tools.remove(id);
      _hidden.remove(id);
      switch (target) {
        case _Placement.bottomBar:
          if (_middle.length >= NavigationDestinations.maxMiddleSlots) {
            _tools.add(_middle.removeLast());
          }
          _middle.insert(
            (index ?? _middle.length).clamp(0, _middle.length).toInt(),
            id,
          );
          break;
        case _Placement.tools:
          _tools.insert(
            (index ?? _tools.length).clamp(0, _tools.length).toInt(),
            id,
          );
          break;
        case _Placement.hidden:
          _hidden.add(id);
          break;
      }
    });
    await _persist();
  }

  List<NavigationDestinationId> _itemsFor(_Placement placement) =>
      switch (placement) {
        _Placement.bottomBar => _middle,
        _Placement.tools => _tools,
        _Placement.hidden => _hidden.toList(),
      };

  void _showBlockedMove() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10nTextRead('This item cannot be moved there.')),
      ),
    );
  }

  Future<void> _reset() async {
    await AdvancedSettingsService.instance.resetNavigationLayout();
    if (!mounted) return;
    setState(_loadLayout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(context.l10nText('Navigation & Tools')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _reset,
            child: Text(context.l10nText('Reset to default')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _sectionTitle(context, 'Bottom bar'),
          _lockedTile(context, NavigationDestinations.home),
          _dropSection(context, _middle, _Placement.bottomBar),
          _lockedTile(context, NavigationDestinations.you),
          if (_middle.length <= NavigationDestinations.minMiddleSlots)
            _hint(context, 'At least one middle destination is required.'),
          if (_middle.length >= NavigationDestinations.maxMiddleSlots)
            _hint(
              context,
              'The bottom bar supports up to '
              '${NavigationDestinations.maxMiddleSlots} middle destinations.',
            ),
          const SizedBox(height: 18),
          _sectionTitle(context, 'Tools button'),
          _dropSection(context, _tools, _Placement.tools),
          if (_tools.isEmpty)
            _hint(context, 'The Tools button is hidden when it has no items.'),
          const SizedBox(height: 18),
          _sectionTitle(context, 'Hidden'),
          _dropSection(context, _hidden.toList(), _Placement.hidden),
          _hint(context, 'Spending Map cannot be hidden.'),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          context.l10nText(title),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          context.l10nText(text),
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 12,
          ),
        ),
      );

  Widget _lockedTile(
    BuildContext context,
    NavigationDestination destination,
  ) =>
      _destinationTile(
        context,
        destination.id,
        locked: true,
      );

  Widget _dropSection(
    BuildContext context,
    List<NavigationDestinationId> items,
    _Placement placement,
  ) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++)
          _dropRow(context, items[index], placement, index),
        _dropZone(
          context,
          placement,
          items.length,
          items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    context.l10nText('No items'),
                    style: TextStyle(color: AppColors.textTertiary(context)),
                  ),
                )
              : const SizedBox(height: 20),
        ),
      ],
    );
  }

  Widget _dropZone(
    BuildContext context,
    _Placement placement,
    int index,
    Widget child,
  ) =>
      DragTarget<NavigationDestinationId>(
        onWillAcceptWithDetails: (details) => _canDrop(details.data, placement),
        onAcceptWithDetails: (details) =>
            _dropOn(details.data, placement, index: index),
        builder: (context, candidateData, rejectedData) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? AppColors.primaryLight.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: candidateData.isNotEmpty
                ? Border.all(color: AppColors.primaryLight)
                : null,
          ),
          child: child,
        ),
      );

  Widget _dropRow(
    BuildContext context,
    NavigationDestinationId id,
    _Placement placement,
    int index,
  ) =>
      DragTarget<NavigationDestinationId>(
        onWillAcceptWithDetails: (details) => _canDrop(details.data, placement),
        onAcceptWithDetails: (details) =>
            _dropOn(details.data, placement, index: index),
        builder: (context, candidateData, rejectedData) =>
            LongPressDraggable<NavigationDestinationId>(
          data: id,
          maxSimultaneousDrags: _saving ? 0 : 1,
          onDraggableCanceled: (_, __) => _showBlockedMove(),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 44,
              child: _destinationTile(context, id),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: _destinationTile(context, id, dragging: true),
          ),
          child: _destinationTile(
            context,
            id,
            dragging: candidateData.isNotEmpty,
          ),
        ),
      );

  Widget _destinationTile(
    BuildContext context,
    NavigationDestinationId id, {
    bool locked = false,
    bool dragging = false,
  }) {
    final destination = NavigationDestinations.get(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: dragging
            ? AppColors.primaryLight.withValues(alpha: 0.10)
            : AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dragging
              ? AppColors.primaryLight
              : AppColors.borderColor(context),
        ),
      ),
      child: ListTile(
        leading: Icon(
          destination.inactiveIcon,
          color: AppColors.primaryLight,
          size: 20,
        ),
        title: Text(
          destination.localizedLabel(context),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: locked
            ? Icon(
                AppIcons.lock_outline_rounded,
                color: AppColors.textTertiary(context),
              )
            : Icon(
                Icons.drag_handle,
                color: AppColors.textTertiary(context),
              ),
      ),
    );
  }
}

enum _Placement { bottomBar, tools, hidden }
