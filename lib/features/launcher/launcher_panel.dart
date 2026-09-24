import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/app_launcher_service.dart';
import '../../core/services/layer_shell_service.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/calculator_evaluator.dart';
import '../shelf/app_icon_widget.dart';

class LauncherPanel extends StatefulWidget {
  final VoidCallback onClose;

  const LauncherPanel({super.key, required this.onClose});

  @override
  State<LauncherPanel> createState() => _LauncherPanelState();
}

class _LauncherPanelState extends State<LauncherPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    AppLauncherService().loadApps().then((_) {
      if (mounted) setState(() {});
    });

    // Request keyboard interactivity from Wayland so user can type in search
    LayerShellService.setKeyboardMode(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    LayerShellService.setKeyboardMode(false);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(
    String val, {
    CalculationResult? calcResult,
    List<SessionAction>? sessionActions,
    List<DesktopAppInfo>? filteredApps,
  }) {
    if (calcResult != null) {
      Clipboard.setData(ClipboardData(text: calcResult.formattedResult));
      widget.onClose();
      return;
    }

    if (sessionActions != null && sessionActions.isNotEmpty) {
      sessionActions.first.execute();
      widget.onClose();
      return;
    }

    if (filteredApps != null && filteredApps.isNotEmpty) {
      filteredApps.first.launch();
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allApps = AppLauncherService().installedApps;

    final calcResult = _searchQuery.isNotEmpty
        ? CalculatorEvaluator.tryEvaluate(_searchQuery)
        : null;

    final sessionActions = _searchQuery.isNotEmpty
        ? SessionService.search(_searchQuery)
        : const <SessionAction>[];

    final filteredApps = _searchQuery.isEmpty
        ? allApps
        : allApps.where((app) {
            return app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (app.comment != null &&
                    app.comment!.toLowerCase().contains(_searchQuery.toLowerCase()));
          }).toList();

    return Container(
      width: 440,
      height: 520,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field (ChromeOS Omnibar style)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (val) => setState(() => _searchQuery = val),
              onSubmitted: (val) => _handleSubmitted(
                val,
                calcResult: calcResult,
                sessionActions: sessionActions,
                filteredApps: filteredApps,
              ),
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search apps, calculate, or system commands...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Symbols.search_rounded,
                  fill: 1,
                  weight: 300,
                  grade: 0,
                  color: colorScheme.primary,
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Symbols.close_rounded,
                          fill: 1,
                          weight: 300,
                          grade: 0,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Calculator Result Card (if math expression detected)
          if (calcResult != null) ...[
            _CalculatorResultCard(
              result: calcResult,
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: calcResult.formattedResult),
                );
                widget.onClose();
              },
            ),
            const SizedBox(height: 12),
          ],

          // Session Action Tiles (if keywords like lock, reboot, shutdown match)
          if (sessionActions.isNotEmpty) ...[
            ...sessionActions.map((action) => _SessionActionTile(
                  action: action,
                  onTap: () {
                    action.execute();
                    widget.onClose();
                  },
                )),
            const SizedBox(height: 10),
          ],

          // Section Header Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _searchQuery.isEmpty ? 'All Applications' : 'Search Results',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Roboto',
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // App Grid / Empty View
          Expanded(
            child: filteredApps.isEmpty && calcResult == null && sessionActions.isEmpty
                ? Center(
                    child: Text(
                      'No applications or commands found',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      return _AppGridTile(
                        app: app,
                        onTap: () {
                          app.launch();
                          widget.onClose();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorResultCard extends StatelessWidget {
  final CalculationResult result;
  final VoidCallback onTap;

  const _CalculatorResultCard({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Symbols.calculate_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.expression,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '= ${result.formattedResult}',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.content_copy_rounded,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionActionTile extends StatelessWidget {
  final SessionAction action;
  final VoidCallback onTap;

  const _SessionActionTile({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                action.icon,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.title,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    action.description,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Symbols.arrow_forward_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppGridTile extends StatefulWidget {
  final DesktopAppInfo app;
  final VoidCallback onTap;

  const _AppGridTile({required this.app, required this.onTap});

  @override
  State<_AppGridTile> createState() => _AppGridTileState();
}

class _AppGridTileState extends State<_AppGridTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Genuine Desktop Icon (SVG / PNG from Papirus / system)
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: AppIconWidget(
                    iconName: widget.app.iconName,
                    appName: widget.app.name,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // App Name
              Text(
                widget.app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Roboto',
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
