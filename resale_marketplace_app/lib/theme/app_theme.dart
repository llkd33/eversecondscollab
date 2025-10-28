import 'package:flutter/material.dart';

class AppTheme {
  // 로고 기반 브랜드 컬러 팔레트
  // 메인 색상: 노란색 계열
  static const Color primaryColor = Color(0xFFE6C757);  // 따뜻한 노란색
  static const Color primaryLight = Color(0xFFF0D77F);
  static const Color primaryDark = Color(0xFFD4B042);
  
  // 보조 색상: 청록색 계열
  static const Color secondaryColor = Color(0xFF5FAAAA);  // 청록색
  static const Color secondaryLight = Color(0xFF7FC4C4);
  static const Color secondaryDark = Color(0xFF4A9090);
  
  // 포인트 색상: 주황색 계열
  static const Color accentColor = Color(0xFFD68A4C);  // 따뜻한 주황색
  static const Color accentLight = Color(0xFFE5A670);
  static const Color accentDark = Color(0xFFC17438);
  
  // 그라데이션 색상 (로고에서 추출)
  static const Color gradientYellow = Color(0xFFEDD170);
  static const Color gradientGreen = Color(0xFF7ABB9F);
  static const Color gradientBlue = Color(0xFF6FA8C5);
  static const Color gradientOrange = Color(0xFFDB9A5B);
  
  // 중성 컬러
  static const Color backgroundColor = Color(0xFFFFFDF8);  // 따뜻한 아이보리 배경
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color dividerColor = Color(0xFFE8E3D3);
  
  // 텍스트 컬러
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFB8B8B8);
  static const Color textDisabled = Color(0xFF9E9E9E);
  
  // 상태 컬러
  static const Color successColor = Color(0xFF7ABB9F);  // 로고의 그린톤 활용
  static const Color warningColor = Color(0xFFE6C757);   // 로고의 옐로톤 활용
  static const Color errorColor = Color(0xFFE57373);
  static const Color infoColor = Color(0xFF6FA8C5);     // 로고의 블루톤 활용
  
  // 그라데이션 (로고 스타일)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientYellow, gradientGreen, gradientBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [gradientGreen, gradientBlue, gradientOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFFFDF8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // 그림자
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A7ABB9F),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x147ABB9F),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
  
  // 간격
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  
  // 반지름
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        error: errorColor,
        surface: surfaceColor,
        background: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      
      // AppBar 테마
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(
          color: textPrimary,
        ),
      ),
      
      // BottomNavigationBar 테마
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),
      
      // Card 테마
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        ),
        color: surfaceColor,
        shadowColor: gradientGreen.withOpacity(0.2),
      ),
      
      // ElevatedButton 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // OutlinedButton 테마
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // TextButton 테마
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // InputDecoration 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: secondaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textHint),
      ),
      
      // Chip 테마
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.1),
        selectedColor: primaryColor,
        deleteIconColor: accentColor,
        labelStyle: const TextStyle(color: textPrimary),
        secondarySelectedColor: secondaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
        ),
      ),
      
      // FloatingActionButton 테마
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      
      // ListTile 테마
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 40,
        iconColor: secondaryColor,
      ),
      
      // Divider 테마
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

// 공통 스타일 상수
class AppStyles {
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppTheme.textSecondary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppTheme.textSecondary,
  );
  
  static const TextStyle priceText = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppTheme.accentColor,
  );
  
  static const TextStyle levelBadge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: AppTheme.secondaryColor,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppTheme.textHint,
  );
}

// 공통 패딩 및 마진
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

// 그라데이션 컨테이너 위젯
class GradientContainer extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const GradientContainer({
    Key? key,
    required this.child,
    this.gradient,
    this.padding,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? AppTheme.primaryGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: child,
    );
  }
}