import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/search_filter_model.dart';
import '../models/product_model.dart';
import '../config/supabase_config.dart';
import '../utils/app_logger.dart';

/// 🔍 Enhanced Search Service
/// Advanced product search with filters, history, and saved searches
class EnhancedSearchService {
  static const String _searchHistoryKey = 'search_history';
  static const String _savedSearchesKey = 'saved_searches';
  static const int _maxHistoryItems = 50;

  final _supabase = SupabaseConfig.client;
  final _logger = AppLogger.scoped('EnhancedSearch');

  /// Search products with advanced filters
  Future<List<ProductModel>> searchProducts(
    SearchFilterModel filter, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      _logger.d(
        'Searching products with filters: ${filter.activeFilterCount} active',
      );

      final query = _supabase
          .from('products')
          .select('*, users!seller_id(name, profile_image)');

      // Apply text search
      if (filter.query != null && filter.query!.isNotEmpty) {
        final queryText = filter.query!;
        query.or(
          'title.ilike.%$queryText%,'
          'description.ilike.%$queryText%,'
          'category.ilike.%$queryText%',
        );
      }

      // Apply category filter
      if (filter.category != null) {
        query.eq('category', filter.category!);
      }

      // Apply price range filter
      if (filter.minPrice != null) {
        query.gte('price', filter.minPrice!);
      }
      if (filter.maxPrice != null) {
        query.lte('price', filter.maxPrice!);
      }

      // Apply resale filter
      if (filter.resaleEnabled != null) {
        query.eq('resale_enabled', filter.resaleEnabled!);
      }

      // Only show products that are for sale
      query.eq('status', '판매중');

      final response = await query
          .order(
            filter.sortBy.orderByColumn,
            ascending: filter.sortBy.isAscending,
          )
          .range(offset, offset + limit - 1);

      final products = response
          .cast<Map<String, dynamic>>()
          .map((json) => ProductModel.fromJson(json))
          .toList();

      _logger.i('Found ${products.length} products');
      return products;
    } catch (e, stackTrace) {
      _logger.e('Failed to search products', e, stackTrace);
      return [];
    }
  }

  /// Get search suggestions based on partial query
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.length < 2) return [];

    try {
      // Get suggestions from product titles and categories
      final response = await _supabase
          .from('products')
          .select('title, category')
          .or('title.ilike.%$query%,category.ilike.%$query%')
          .limit(10);

      final suggestions = <String>{};

      for (final item in response) {
        final title = item['title'] as String?;
        final category = item['category'] as String?;

        if (title != null && title.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(title);
        }
        if (category != null && category.toLowerCase().contains(query.toLowerCase())) {
          suggestions.add(category);
        }
      }

      return suggestions.toList();
    } catch (e) {
      _logger.w('Failed to get search suggestions', e);
      return [];
    }
  }

  /// Save search query to history
  Future<void> saveToHistory(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey);

      List<SearchHistoryEntry> history = [];
      if (historyJson != null) {
        final List<dynamic> decoded = json.decode(historyJson);
        history = decoded.map((e) => SearchHistoryEntry.fromJson(e)).toList();
      }

      // Remove duplicate if exists
      history.removeWhere((e) => e.query.toLowerCase() == query.toLowerCase());

      // Add new entry at the beginning
      history.insert(0, SearchHistoryEntry(
        query: query,
        timestamp: DateTime.now(),
      ));

      // Keep only recent entries
      if (history.length > _maxHistoryItems) {
        history = history.sublist(0, _maxHistoryItems);
      }

      // Save back to preferences
      final encoded = json.encode(history.map((e) => e.toJson()).toList());
      await prefs.setString(_searchHistoryKey, encoded);

      _logger.d('Saved search to history: $query');
    } catch (e) {
      _logger.w('Failed to save search history', e);
    }
  }

  /// Get search history
  Future<List<SearchHistoryEntry>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey);

      if (historyJson == null) return [];

      final List<dynamic> decoded = json.decode(historyJson);
      return decoded.map((e) => SearchHistoryEntry.fromJson(e)).toList();
    } catch (e) {
      _logger.w('Failed to get search history', e);
      return [];
    }
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
      _logger.i('Cleared search history');
    } catch (e) {
      _logger.w('Failed to clear search history', e);
    }
  }

  /// Save a search filter for later
  Future<void> saveSearch(String name, SearchFilterModel filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_savedSearchesKey);

      List<SavedSearch> saved = [];
      if (savedJson != null) {
        final List<dynamic> decoded = json.decode(savedJson);
        saved = decoded.map((e) => SavedSearch.fromJson(e)).toList();
      }

      // Create new saved search
      final newSaved = SavedSearch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        filter: filter,
        createdAt: DateTime.now(),
      );

      saved.add(newSaved);

      // Save back
      final encoded = json.encode(saved.map((e) => e.toJson()).toList());
      await prefs.setString(_savedSearchesKey, encoded);

      _logger.i('Saved search: $name');
    } catch (e) {
      _logger.e('Failed to save search', e);
    }
  }

  /// Get saved searches
  Future<List<SavedSearch>> getSavedSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_savedSearchesKey);

      if (savedJson == null) return [];

      final List<dynamic> decoded = json.decode(savedJson);
      return decoded.map((e) => SavedSearch.fromJson(e)).toList();
    } catch (e) {
      _logger.w('Failed to get saved searches', e);
      return [];
    }
  }

  /// Delete a saved search
  Future<void> deleteSavedSearch(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_savedSearchesKey);

      if (savedJson == null) return;

      final List<dynamic> decoded = json.decode(savedJson);
      final saved = decoded.map((e) => SavedSearch.fromJson(e)).toList();

      saved.removeWhere((s) => s.id == id);

      final encoded = json.encode(saved.map((e) => e.toJson()).toList());
      await prefs.setString(_savedSearchesKey, encoded);

      _logger.i('Deleted saved search: $id');
    } catch (e) {
      _logger.w('Failed to delete saved search', e);
    }
  }

  /// Toggle notifications for a saved search
  Future<bool> toggleNotifications(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_savedSearchesKey);

      if (savedJson == null) {
        throw Exception('No saved searches found');
      }

      final List<dynamic> decoded = json.decode(savedJson);
      final saved = decoded.map((e) => SavedSearch.fromJson(e)).toList();

      bool? toggled;
      for (var i = 0; i < saved.length; i++) {
        if (saved[i].id == id) {
          final current = saved[i];
          final updated = SavedSearch(
            id: current.id,
            name: current.name,
            filter: current.filter,
            createdAt: current.createdAt,
            notificationsEnabled: !current.notificationsEnabled,
          );
          saved[i] = updated;
          toggled = updated.notificationsEnabled;
          break;
        }
      }

      if (toggled == null) {
        throw Exception('Saved search not found');
      }

      final encoded = json.encode(saved.map((e) => e.toJson()).toList());
      await prefs.setString(_savedSearchesKey, encoded);

      _logger.i(
        'Toggled notifications for saved search $id → ${toggled ? "enabled" : "disabled"}',
      );

      return toggled;
    } catch (e, stackTrace) {
      _logger.e('Failed to toggle notifications for saved search $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get popular search queries
  Future<List<String>> getPopularSearches() async {
    try {
      // In a real implementation, this would track searches across all users
      // For now, return some common categories
      return [
        '의류',
        '전자기기',
        '생활용품',
        '도서',
        '스포츠/레저',
      ];
    } catch (e) {
      _logger.w('Failed to get popular searches', e);
      return [];
    }
  }
}
