import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/app_launcher_service.dart';
import '../shelf/app_icon_widget.dart';
import '../../core/services/layer_shell_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allApps = AppLauncherService().installedApps;

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
          // Search Field (ChromeOS style)
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
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Roboto',
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search your apps, web...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontFamily: 'Roboto',
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

          const SizedBox(height: 16),

          // Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _searchQuery.isEmpty ? 'All Applications' : 'Search Results',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // App Grid
          Expanded(
            child: filteredApps.isEmpty
                ? Center(
                    child: Text(
                      'No applications found',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'Roboto',
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
                  fontWeight: FontWeight.w500,
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
