import 'package:flutter/material.dart';

/// 반응형 브레이크포인트 정의
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1800;
}

/// 디바이스 타입 열거형
enum DeviceType { mobile, tablet, desktop, largeDesktop }

/// 반응형 정보를 제공하는 클래스
class ResponsiveInfo {
  final DeviceType deviceType;
  final Size screenSize;
  final double width;
  final double height;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final bool isLargeDesktop;
  final Orientation orientation;
  final double pixelRatio;
  
  ResponsiveInfo({
    required this.deviceType,
    required this.screenSize,
    required this.width,
    required this.height,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.isLargeDesktop,
    required this.orientation,
    required this.pixelRatio,
  });
  
  /// 현재 컨텍스트에서 ResponsiveInfo 생성
  factory ResponsiveInfo.of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    
    DeviceType deviceType;
    if (width < Breakpoints.mobile) {
      deviceType = DeviceType.mobile;
    } else if (width < Breakpoints.tablet) {
      deviceType = DeviceType.tablet;
    } else if (width < Breakpoints.desktop) {
      deviceType = DeviceType.desktop;
    } else {
      deviceType = DeviceType.largeDesktop;
    }
    
    return ResponsiveInfo(
      deviceType: deviceType,
      screenSize: mediaQuery.size,
      width: width,
      height: height,
      isMobile: width < Breakpoints.mobile,
      isTablet: width >= Breakpoints.mobile && width < Breakpoints.tablet,
      isDesktop: width >= Breakpoints.tablet && width < Breakpoints.desktop,
      isLargeDesktop: width >= Breakpoints.desktop,
      orientation: mediaQuery.orientation,
      pixelRatio: mediaQuery.devicePixelRatio,
    );
  }
  
  /// 적응형 값 반환
  T adaptive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
    }
  }
  
  /// 반응형 패딩 계산
  EdgeInsets responsivePadding({
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
    EdgeInsets? largeDesktop,
  }) {
    return adaptive(
      mobile: mobile ?? const EdgeInsets.all(16),
      tablet: tablet ?? const EdgeInsets.all(24),
      desktop: desktop ?? const EdgeInsets.all(32),
      largeDesktop: largeDesktop ?? const EdgeInsets.all(48),
    );
  }
  
  /// 반응형 폰트 크기 계산
  double responsiveFontSize(double baseSize) {
    final scaleFactor = adaptive(
      mobile: 1.0,
      tablet: 1.1,
      desktop: 1.15,
      largeDesktop: 1.2,
    );
    return baseSize * scaleFactor;
  }
}

/// 반응형 레이아웃 위젯
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;
  
  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: info.adaptive(
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
        largeDesktop: largeDesktop,
      ),
    );
  }
}

/// 반응형 빌더 위젯
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveInfo info) builder;
  
  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final info = ResponsiveInfo.of(context);
        return builder(context, info);
      },
    );
  }
}

/// 반응형 그리드 시스템
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeDesktopColumns;
  
  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.largeDesktopColumns = 4,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    final columns = info.adaptive(
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
      largeDesktop: largeDesktopColumns,
    );
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: 1,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// 반응형 컨테이너
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Alignment alignment;
  
  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
    this.alignment = Alignment.topCenter,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    
    final adaptiveMaxWidth = maxWidth ?? info.adaptive(
      mobile: double.infinity,
      tablet: 768,
      desktop: 1024,
      largeDesktop: 1440,
    );
    
    final adaptivePadding = padding ?? info.responsivePadding();
    
    return Container(
      alignment: alignment,
      margin: margin,
      child: Container(
        constraints: BoxConstraints(maxWidth: adaptiveMaxWidth),
        padding: adaptivePadding,
        child: child,
      ),
    );
  }
}

/// 반응형 Row/Column 위젯
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment columnMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final double spacing;
  
  const ResponsiveRowColumn({
    Key? key,
    required this.children,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 16,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    
    if (info.isMobile) {
      return Column(
        mainAxisAlignment: columnMainAxisAlignment,
        crossAxisAlignment: columnCrossAxisAlignment,
        children: _addSpacing(children, true),
      );
    }
    
    return Row(
      mainAxisAlignment: rowMainAxisAlignment,
      crossAxisAlignment: rowCrossAxisAlignment,
      children: _addSpacing(
        children.map((child) => Expanded(child: child)).toList(),
        false,
      ),
    );
  }
  
  List<Widget> _addSpacing(List<Widget> widgets, bool isColumn) {
    if (widgets.isEmpty) return widgets;
    
    final spacedWidgets = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      spacedWidgets.add(widgets[i]);
      if (i < widgets.length - 1) {
        spacedWidgets.add(
          isColumn
              ? SizedBox(height: spacing)
              : SizedBox(width: spacing),
        );
      }
    }
    return spacedWidgets;
  }
}

/// 반응형 텍스트 위젯
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double mobileFontSize;
  final double? tabletFontSize;
  final double? desktopFontSize;
  
  const ResponsiveText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.mobileFontSize = 14,
    this.tabletFontSize,
    this.desktopFontSize,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    
    final fontSize = info.adaptive(
      mobile: mobileFontSize,
      tablet: tabletFontSize ?? mobileFontSize * 1.1,
      desktop: desktopFontSize ?? mobileFontSize * 1.2,
    );
    
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 반응형 앱바
class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  
  const ResponsiveAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    
    if (info.isDesktop || info.isLargeDesktop) {
      // 데스크톱: 커스텀 헤더
      return Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: Theme.of(context).appBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (leading != null) leading!,
            if (leading != null) const SizedBox(width: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            if (actions != null) ...actions!,
          ],
        ),
      );
    }
    
    // 모바일/태블릿: 일반 AppBar
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// 반응형 네비게이션
class ResponsiveNavigation extends StatelessWidget {
  final int currentIndex;
  final List<NavigationItem> items;
  final ValueChanged<int> onIndexChanged;
  
  const ResponsiveNavigation({
    Key? key,
    required this.currentIndex,
    required this.items,
    required this.onIndexChanged,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    
    if (info.isDesktop || info.isLargeDesktop) {
      // 데스크톱: 사이드 네비게이션
      return NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: onIndexChanged,
        extended: info.isLargeDesktop,
        destinations: items
            .map((item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon ?? item.icon),
                  label: Text(item.label),
                ))
            .toList(),
      );
    }
    
    // 모바일/태블릿: 하단 네비게이션
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onIndexChanged,
      type: BottomNavigationBarType.fixed,
      items: items
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.selectedIcon ?? item.icon),
                label: item.label,
              ))
          .toList(),
    );
  }
}

/// 네비게이션 아이템 모델
class NavigationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  
  const NavigationItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

/// 반응형 다이얼로그
class ResponsiveDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget>? actions;
  
  const ResponsiveDialog({
    Key? key,
    required this.title,
    required this.content,
    this.actions,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    
    final maxWidth = info.adaptive(
      mobile: info.width * 0.9,
      tablet: 500.0,
      desktop: 600.0,
      largeDesktop: 700.0,
    );
    
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: info.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: title,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: content,
              ),
            ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}