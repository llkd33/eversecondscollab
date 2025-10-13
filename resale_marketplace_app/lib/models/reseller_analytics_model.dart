/// 📊 Reseller Analytics Model
/// Comprehensive analytics for resale marketplace participants
class ResellerAnalytics {
  // Overview metrics
  final int totalProducts;
  final int activeProducts;
  final int soldProducts;
  final int totalEarnings;
  final int totalCommissions;
  final double conversionRate;

  // Time-based metrics
  final Map<String, int> salesByMonth;
  final Map<String, int> earningsByMonth;
  final Map<String, int> viewsByDay;

  // Product performance
  final List<ProductPerformance> topPerformingProducts;
  final List<ProductPerformance> underperformingProducts;

  // Commission tracking
  final int pendingCommissions;
  final int paidCommissions;
  final DateTime? lastPayoutDate;
  final DateTime? nextPayoutDate;

  // Customer insights
  final int uniqueBuyers;
  final double avgOrderValue;
  final double repeatCustomerRate;

  ResellerAnalytics({
    required this.totalProducts,
    required this.activeProducts,
    required this.soldProducts,
    required this.totalEarnings,
    required this.totalCommissions,
    required this.conversionRate,
    required this.salesByMonth,
    required this.earningsByMonth,
    required this.viewsByDay,
    required this.topPerformingProducts,
    required this.underperformingProducts,
    required this.pendingCommissions,
    required this.paidCommissions,
    this.lastPayoutDate,
    this.nextPayoutDate,
    required this.uniqueBuyers,
    required this.avgOrderValue,
    required this.repeatCustomerRate,
  });

  factory ResellerAnalytics.empty() {
    return ResellerAnalytics(
      totalProducts: 0,
      activeProducts: 0,
      soldProducts: 0,
      totalEarnings: 0,
      totalCommissions: 0,
      conversionRate: 0.0,
      salesByMonth: {},
      earningsByMonth: {},
      viewsByDay: {},
      topPerformingProducts: [],
      underperformingProducts: [],
      pendingCommissions: 0,
      paidCommissions: 0,
      uniqueBuyers: 0,
      avgOrderValue: 0.0,
      repeatCustomerRate: 0.0,
    );
  }
}

/// Product performance metrics
class ProductPerformance {
  final String productId;
  final String productTitle;
  final String? productImage;
  final int views;
  final int favorites;
  final int inquiries;
  final int sales;
  final double conversionRate;
  final int revenue;
  final int commissionEarned;
  final DateTime listedAt;
  final DateTime? soldAt;

  ProductPerformance({
    required this.productId,
    required this.productTitle,
    this.productImage,
    required this.views,
    required this.favorites,
    required this.inquiries,
    required this.sales,
    required this.conversionRate,
    required this.revenue,
    required this.commissionEarned,
    required this.listedAt,
    this.soldAt,
  });

  // Performance score (0-100)
  int get performanceScore {
    int score = 0;

    // Views contribute 20 points
    score += (views / 100 * 20).clamp(0, 20).toInt();

    // Conversion rate contributes 30 points
    score += (conversionRate * 30).toInt();

    // Sales contribute 30 points
    score += (sales * 10).clamp(0, 30).toInt();

    // Inquiries contribute 20 points
    score += (inquiries / 5 * 20).clamp(0, 20).toInt();

    return score.clamp(0, 100);
  }

  String get performanceLevel {
    final score = performanceScore;
    if (score >= 80) return '우수';
    if (score >= 60) return '양호';
    if (score >= 40) return '보통';
    if (score >= 20) return '저조';
    return '매우 저조';
  }
}

/// Commission payout record
class CommissionPayout {
  final String id;
  final int amount;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime paidAt;
  final String status; // pending, processing, paid, failed
  final String? transactionId;
  final int transactionCount;

  CommissionPayout({
    required this.id,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    required this.paidAt,
    required this.status,
    this.transactionId,
    required this.transactionCount,
  });
}

/// Earnings forecast
class EarningsForecast {
  final Map<String, double> nextMonthForecast;
  final double confidenceLevel;
  final String trendDirection; // up, down, stable
  final double projectedGrowth;

  EarningsForecast({
    required this.nextMonthForecast,
    required this.confidenceLevel,
    required this.trendDirection,
    required this.projectedGrowth,
  });
}

/// Reseller performance comparison
class PerformanceComparison {
  final double myConversionRate;
  final double avgConversionRate;
  final double myAvgOrderValue;
  final double avgOrderValue;
  final int myRanking;
  final int totalResellers;
  final String performanceTier; // top, high, medium, low

  PerformanceComparison({
    required this.myConversionRate,
    required this.avgConversionRate,
    required this.myAvgOrderValue,
    required this.avgOrderValue,
    required this.myRanking,
    required this.totalResellers,
    required this.performanceTier,
  });

  double get conversionRateDiff => myConversionRate - avgConversionRate;
  double get orderValueDiff => myAvgOrderValue - avgOrderValue;
  double get topPercentile => (myRanking / totalResellers) * 100;
}
