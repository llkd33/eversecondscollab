import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../models/report_model.dart';

/// Admin service for dashboard and management operations
class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get total users count
      final usersResponse = await _supabase
          .from('users')
          .select('id')
          .count();
      final totalUsers = usersResponse.count ?? 0;

      // Get active users (users who logged in within last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final activeUsersResponse = await _supabase
          .from('users')
          .select('id')
          .gte('last_login_at', thirtyDaysAgo)
          .count();
      final activeUsers = activeUsersResponse.count ?? 0;

      // Get total products count
      final productsResponse = await _supabase
          .from('products')
          .select('id')
          .count();
      final totalProducts = productsResponse.count ?? 0;

      // Get active products (not sold)
      final activeProductsResponse = await _supabase
          .from('products')
          .select('id')
          .eq('status', 'active')
          .count();
      final activeProducts = activeProductsResponse.count ?? 0;

      // Get total transactions
      final transactionsResponse = await _supabase
          .from('transactions')
          .select('id')
          .count();
      final totalTransactions = transactionsResponse.count ?? 0;

      // Get completed transactions
      final completedTransactionsResponse = await _supabase
          .from('transactions')
          .select('id, total_amount')
          .eq('status', 'completed');
      final completedTransactions = completedTransactionsResponse.length;
      
      // Calculate total revenue
      double totalRevenue = 0;
      for (final transaction in completedTransactionsResponse) {
        totalRevenue += (transaction['total_amount'] ?? 0).toDouble();
      }

      // Get pending reports count
      final pendingReportsResponse = await _supabase
          .from('reports')
          .select('id')
          .eq('status', 'pending')
          .count();
      final pendingReports = pendingReportsResponse.count ?? 0;

      // Get new users today
      final todayStart = DateTime.now().toIso8601String().split('T')[0];
      final newUsersResponse = await _supabase
          .from('users')
          .select('id')
          .gte('created_at', todayStart)
          .count();
      final newUsersToday = newUsersResponse.count ?? 0;

      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'totalProducts': totalProducts,
        'activeProducts': activeProducts,
        'totalTransactions': totalTransactions,
        'completedTransactions': completedTransactions,
        'pendingReports': pendingReports,
        'totalRevenue': totalRevenue,
        'newUsersToday': newUsersToday,
      };
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      // Return default values on error
      return {
        'totalUsers': 0,
        'activeUsers': 0,
        'totalProducts': 0,
        'activeProducts': 0,
        'totalTransactions': 0,
        'completedTransactions': 0,
        'pendingReports': 0,
        'totalRevenue': 0.0,
        'newUsersToday': 0,
      };
    }
  }

  /// Get monthly statistics for charts
  Future<List<Map<String, dynamic>>> getMonthlyStats() async {
    try {
      final List<Map<String, dynamic>> monthlyData = [];
      final now = DateTime.now();

      // Get stats for last 6 months
      for (int i = 5; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final monthStart = monthDate.toIso8601String();
        final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59)
            .toIso8601String();

        // Get transactions for this month
        final transactionsResponse = await _supabase
            .from('transactions')
            .select('total_amount')
            .gte('created_at', monthStart)
            .lte('created_at', monthEnd)
            .eq('status', 'completed');

        double monthRevenue = 0;
        int transactionCount = transactionsResponse.length;
        for (final transaction in transactionsResponse) {
          monthRevenue += (transaction['total_amount'] ?? 0).toDouble();
        }

        // Get new users for this month
        final usersResponse = await _supabase
            .from('users')
            .select('id')
            .gte('created_at', monthStart)
            .lte('created_at', monthEnd)
            .count();
        final newUsers = usersResponse.count ?? 0;

        monthlyData.add({
          'month': _getMonthName(monthDate.month),
          'revenue': monthRevenue,
          'transactions': transactionCount,
          'newUsers': newUsers,
        });
      }

      return monthlyData;
    } catch (e) {
      print('Error fetching monthly stats: $e');
      return [];
    }
  }

  /// Get category statistics
  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    try {
      final response = await _supabase
          .from('products')
          .select('category');

      final Map<String, int> categoryCount = {};
      for (final product in response) {
        final category = product['category'] ?? '기타';
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }

      return categoryCount.entries.map((entry) => {
        'category': entry.key,
        'count': entry.value,
        'percentage': 0.0, // Will be calculated in UI
      }).toList();
    } catch (e) {
      print('Error fetching category stats: $e');
      return [];
    }
  }

  /// Get recent activities
  Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 10}) async {
    try {
      final List<Map<String, dynamic>> activities = [];

      // Get recent user registrations
      final newUsersResponse = await _supabase
          .from('users')
          .select('id, name, created_at')
          .order('created_at', ascending: false)
          .limit(limit ~/ 3);

      for (final user in newUsersResponse) {
        activities.add({
          'type': '신규 가입',
          'user': user['name'] ?? '알 수 없음',
          'userId': user['id'],
          'time': user['created_at'],
          'timestamp': DateTime.parse(user['created_at']).millisecondsSinceEpoch,
        });
      }

      // Get recent products
      final productsResponse = await _supabase
          .from('products')
          .select('id, title, seller_id, created_at, users!products_seller_id_fkey(name)')
          .order('created_at', ascending: false)
          .limit(limit ~/ 3);

      for (final product in productsResponse) {
        activities.add({
          'type': '상품 등록',
          'user': product['users']['name'] ?? '알 수 없음',
          'userId': product['seller_id'],
          'productId': product['id'],
          'productTitle': product['title'],
          'time': product['created_at'],
          'timestamp': DateTime.parse(product['created_at']).millisecondsSinceEpoch,
        });
      }

      // Get recent transactions
      final transactionsResponse = await _supabase
          .from('transactions')
          .select('''
            id, 
            status, 
            created_at, 
            buyer_id,
            seller_id,
            buyer:users!transactions_buyer_id_fkey(name),
            seller:users!transactions_seller_id_fkey(name)
          ''')
          .order('created_at', ascending: false)
          .limit(limit ~/ 3);

      for (final transaction in transactionsResponse) {
        final status = transaction['status'];
        String activityType = '거래 생성';
        if (status == 'completed') {
          activityType = '거래 완료';
        } else if (status == 'cancelled') {
          activityType = '거래 취소';
        }

        activities.add({
          'type': activityType,
          'user': transaction['buyer']['name'] ?? '알 수 없음',
          'userId': transaction['buyer_id'],
          'transactionId': transaction['id'],
          'time': transaction['created_at'],
          'timestamp': DateTime.parse(transaction['created_at']).millisecondsSinceEpoch,
        });
      }

      // Sort activities by timestamp (most recent first)
      activities.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      // Format time for display
      final now = DateTime.now();
      for (final activity in activities) {
        final activityTime = DateTime.fromMillisecondsSinceEpoch(activity['timestamp']);
        activity['displayTime'] = _formatRelativeTime(activityTime, now);
      }

      return activities.take(limit).toList();
    } catch (e) {
      print('Error fetching recent activities: $e');
      return [];
    }
  }

  /// Get users list for management
  Future<List<Map<String, dynamic>>> getUsers({
    int limit = 50,
    int offset = 0,
    String? searchQuery,
    String? filterRole,
    String? filterStatus,
  }) async {
    try {
      var query = _supabase.from('users').select();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$searchQuery%,email.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
      }

      if (filterRole != null && filterRole.isNotEmpty) {
        query = query.eq('role', filterRole);
      }

      if (filterStatus != null && filterStatus.isNotEmpty) {
        query = query.eq('status', filterStatus);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  /// Update user status (block/unblock)
  Future<bool> updateUserStatus(String userId, String status) async {
    try {
      await _supabase
          .from('users')
          .update({'status': status})
          .eq('id', userId);
      return true;
    } catch (e) {
      print('Error updating user status: $e');
      return false;
    }
  }

  /// Delete user
  Future<bool> deleteUser(String userId) async {
    try {
      // Note: This should be handled carefully with proper cascading deletes
      await _supabase
          .from('users')
          .delete()
          .eq('id', userId);
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Get reports for management
  Future<List<Map<String, dynamic>>> getReports({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('reports')
          .select('''
            *,
            reporter:users!reports_reporter_id_fkey(id, name, email),
            reported:users!reports_reported_user_id_fkey(id, name, email)
          ''');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }

  /// Update report status
  Future<bool> updateReportStatus(String reportId, String status, {String? resolvedBy, String? resolution}) async {
    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (resolvedBy != null) {
        updates['resolved_by'] = resolvedBy;
      }
      if (resolution != null) {
        updates['resolution'] = resolution;
      }
      if (status == 'resolved') {
        updates['resolved_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('reports')
          .update(updates)
          .eq('id', reportId);
      return true;
    } catch (e) {
      print('Error updating report status: $e');
      return false;
    }
  }

  // Helper methods
  String _getMonthName(int month) {
    const months = [
      '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월'
    ];
    return months[month - 1];
  }

  String _formatRelativeTime(DateTime time, DateTime now) {
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${time.month}월 ${time.day}일';
    }
  }
}