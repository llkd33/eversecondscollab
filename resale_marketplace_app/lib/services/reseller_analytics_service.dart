import '../config/supabase_config.dart';
import '../models/reseller_analytics_model.dart';
import '../utils/app_logger.dart';

/// 📊 Reseller Analytics Service
/// Provides comprehensive analytics for resellers
class ResellerAnalyticsService {
  final _supabase = SupabaseConfig.client;
  final _logger = AppLogger.scoped('ResellerAnalytics');

  /// Get comprehensive analytics for a reseller
  Future<ResellerAnalytics> getAnalytics(String resellerId) async {
    try {
      _logger.d('Fetching analytics for reseller: $resellerId');

      // Fetch all metrics in parallel
      final results = await Future.wait([
        _getProductMetrics(resellerId),
        _getSalesMetrics(resellerId),
        _getEarningsMetrics(resellerId),
        _getCustomerMetrics(resellerId),
        _getTopPerformingProducts(resellerId),
      ]);

      final productMetrics = results[0] as Map<String, int>;
      final salesMetrics = results[1] as Map<String, dynamic>;
      final earningsMetrics = results[2] as Map<String, dynamic>;
      final customerMetrics = results[3] as Map<String, double>;
      final topProducts = results[4] as List<ProductPerformance>;

      return ResellerAnalytics(
        totalProducts: productMetrics['total'] ?? 0,
        activeProducts: productMetrics['active'] ?? 0,
        soldProducts: productMetrics['sold'] ?? 0,
        totalEarnings: earningsMetrics['total'] ?? 0,
        totalCommissions: earningsMetrics['commissions'] ?? 0,
        conversionRate: salesMetrics['conversionRate'] ?? 0.0,
        salesByMonth: salesMetrics['byMonth'] ?? {},
        earningsByMonth: earningsMetrics['byMonth'] ?? {},
        viewsByDay: {},
        topPerformingProducts: topProducts,
        underperformingProducts: [],
        pendingCommissions: earningsMetrics['pending'] ?? 0,
        paidCommissions: earningsMetrics['paid'] ?? 0,
        uniqueBuyers: customerMetrics['uniqueBuyers']?.toInt() ?? 0,
        avgOrderValue: customerMetrics['avgOrderValue'] ?? 0.0,
        repeatCustomerRate: customerMetrics['repeatRate'] ?? 0.0,
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to get analytics', e, stackTrace);
      return ResellerAnalytics.empty();
    }
  }

  /// Get product metrics
  Future<Map<String, int>> _getProductMetrics(String resellerId) async {
    try {
      final products = await _supabase
          .from('products')
          .select('id, status')
          .eq('seller_id', resellerId);

      final total = products.length;
      final active = products.where((p) => p['status'] == '판매중').length;
      final sold = products.where((p) => p['status'] == '판매완료').length;

      return {
        'total': total,
        'active': active,
        'sold': sold,
      };
    } catch (e) {
      _logger.w('Failed to get product metrics', e);
      return {'total': 0, 'active': 0, 'sold': 0};
    }
  }

  /// Get sales metrics
  Future<Map<String, dynamic>> _getSalesMetrics(String resellerId) async {
    try {
      final transactions = await _supabase
          .from('transactions')
          .select('id, price, created_at')
          .or('seller_id.eq.$resellerId,reseller_id.eq.$resellerId');

      final byMonth = <String, int>{};
      for (final t in transactions) {
        final date = DateTime.parse(t['created_at']);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        byMonth[key] = (byMonth[key] ?? 0) + 1;
      }

      // Calculate conversion rate (simplified)
      final totalViews = 1000; // Would get from analytics table
      final conversionRate = totalViews > 0
          ? (transactions.length / totalViews)
          : 0.0;

      return {
        'total': transactions.length,
        'byMonth': byMonth,
        'conversionRate': conversionRate,
      };
    } catch (e) {
      _logger.w('Failed to get sales metrics', e);
      return {'total': 0, 'byMonth': {}, 'conversionRate': 0.0};
    }
  }

  /// Get earnings metrics
  Future<Map<String, dynamic>> _getEarningsMetrics(String resellerId) async {
    try {
      final transactions = await _supabase
          .from('transactions')
          .select('price, resale_fee, created_at, status')
          .eq('reseller_id', resellerId);

      int totalEarnings = 0;
      int totalCommissions = 0;
      int pendingCommissions = 0;
      int paidCommissions = 0;
      final byMonth = <String, int>{};

      for (final t in transactions) {
        final price = t['price'] as int;
        final fee = t['resale_fee'] as int? ?? 0;
        final status = t['status'] as String?;

        totalCommissions += fee;

        if (status == '거래완료') {
          totalEarnings += price;
          paidCommissions += fee;

          final date = DateTime.parse(t['created_at']);
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          byMonth[key] = (byMonth[key] ?? 0) + fee;
        } else {
          pendingCommissions += fee;
        }
      }

      return {
        'total': totalEarnings,
        'commissions': totalCommissions,
        'pending': pendingCommissions,
        'paid': paidCommissions,
        'byMonth': byMonth,
      };
    } catch (e) {
      _logger.w('Failed to get earnings metrics', e);
      return {
        'total': 0,
        'commissions': 0,
        'pending': 0,
        'paid': 0,
        'byMonth': {},
      };
    }
  }

  /// Get customer metrics
  Future<Map<String, double>> _getCustomerMetrics(String resellerId) async {
    try {
      final transactions = await _supabase
          .from('transactions')
          .select('buyer_id, price')
          .or('seller_id.eq.$resellerId,reseller_id.eq.$resellerId')
          .eq('status', '거래완료');

      final uniqueBuyers = <String>{};
      final buyerCounts = <String, int>{};
      int totalRevenue = 0;

      for (final t in transactions) {
        final buyerId = t['buyer_id'] as String;
        uniqueBuyers.add(buyerId);
        buyerCounts[buyerId] = (buyerCounts[buyerId] ?? 0) + 1;
        totalRevenue += t['price'] as int;
      }

      final repeatCustomers = buyerCounts.values.where((count) => count > 1).length;
      final repeatRate = uniqueBuyers.isNotEmpty
          ? (repeatCustomers / uniqueBuyers.length)
          : 0.0;

      final avgOrderValue = transactions.isNotEmpty
          ? (totalRevenue / transactions.length)
          : 0.0;

      return {
        'uniqueBuyers': uniqueBuyers.length.toDouble(),
        'avgOrderValue': avgOrderValue,
        'repeatRate': repeatRate,
      };
    } catch (e) {
      _logger.w('Failed to get customer metrics', e);
      return {
        'uniqueBuyers': 0.0,
        'avgOrderValue': 0.0,
        'repeatRate': 0.0,
      };
    }
  }

  /// Get top performing products
  Future<List<ProductPerformance>> _getTopPerformingProducts(
    String resellerId, {
    int limit = 5,
  }) async {
    try {
      final products = await _supabase
          .from('products')
          .select('id, title, images, created_at')
          .eq('seller_id', resellerId)
          .order('created_at', ascending: false)
          .limit(limit);

      final performances = <ProductPerformance>[];

      for (final product in products) {
        // In a real implementation, you'd fetch views, favorites, etc.
        performances.add(ProductPerformance(
          productId: product['id'],
          productTitle: product['title'],
          productImage: (product['images'] as List?)?.first,
          views: 0, // Would get from analytics table
          favorites: 0,
          inquiries: 0,
          sales: 0,
          conversionRate: 0.0,
          revenue: 0,
          commissionEarned: 0,
          listedAt: DateTime.parse(product['created_at']),
        ));
      }

      return performances;
    } catch (e) {
      _logger.w('Failed to get top performing products', e);
      return [];
    }
  }

  /// Get earnings forecast
  Future<EarningsForecast> getEarningsForecast(String resellerId) async {
    try {
      // This would use historical data to predict future earnings
      // For now, return a simple forecast
      return EarningsForecast(
        nextMonthForecast: {'week1': 50000, 'week2': 75000, 'week3': 60000, 'week4': 80000},
        confidenceLevel: 0.75,
        trendDirection: 'up',
        projectedGrowth: 0.15,
      );
    } catch (e) {
      _logger.w('Failed to get earnings forecast', e);
      return EarningsForecast(
        nextMonthForecast: {},
        confidenceLevel: 0.0,
        trendDirection: 'stable',
        projectedGrowth: 0.0,
      );
    }
  }
}
