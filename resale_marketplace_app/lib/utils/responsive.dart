import 'package:flutter/material.dart';

class Responsive {
  static double responsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) {
      return baseFontSize * 0.9;
    } else if (screenWidth < 414) {
      return baseFontSize;
    } else if (screenWidth < 768) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize * 1.2;
    }
  }

  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerMaxWidth = maxWidth ?? 1200;
    
    if (screenWidth > containerMaxWidth) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: containerMaxWidth),
          child: child,
        ),
      );
    }
    
    return child;
  }
}

extension ResponsiveContext on BuildContext {
  bool get isMobile {
    final screenWidth = MediaQuery.of(this).size.width;
    return screenWidth < 768;
  }

  bool get isTablet {
    final screenWidth = MediaQuery.of(this).size.width;
    return screenWidth >= 768 && screenWidth < 1024;
  }

  bool get isDesktop {
    final screenWidth = MediaQuery.of(this).size.width;
    return screenWidth >= 1024;
  }

  EdgeInsetsGeometry get responsivePadding {
    if (isMobile) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    } else if (isTablet) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
  }
}