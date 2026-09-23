import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/services/icon_theme_service.dart';

/// Renders authentic Linux desktop application icons (Papirus SVGs, PNGs) with high fidelity.
class AppIconWidget extends StatelessWidget {
  final String iconName;
  final String appName;
  final double size;

  const AppIconWidget({
    super.key,
    required this.iconName,
    this.appName = '',
    this.size = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconPath = IconThemeService().findIcon(iconName);

    if (iconPath != null) {
      if (iconPath.endsWith('.svg')) {
        return SvgPicture.file(
          File(iconPath),
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return Image.file(
          File(iconPath),
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        );
      }
    }

    // Fallback ChromeOS letter monogram circle
    final initial = appName.isNotEmpty
        ? appName.substring(0, 1).toUpperCase()
        : (iconName.isNotEmpty ? iconName.substring(0, 1).toUpperCase() : '?');
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

