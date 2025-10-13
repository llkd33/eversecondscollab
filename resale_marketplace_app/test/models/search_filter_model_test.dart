import 'package:flutter_test/flutter_test.dart';
import 'package:resale_marketplace_app/models/search_filter_model.dart';

void main() {
  group('SearchFilterModel', () {
    test('should create empty filter', () {
      final filter = SearchFilterModel();

      expect(filter.hasFilters, isFalse);
      expect(filter.activeFilterCount, equals(0));
    });

    test('should detect active filters', () {
      final filter = SearchFilterModel(
        category: '의류',
        minPrice: 10000,
        maxPrice: 50000,
      );

      expect(filter.hasFilters, isTrue);
      expect(filter.activeFilterCount, equals(2)); // category + price range
    });

    test('should clear filters while preserving query and sort', () {
      final filter = SearchFilterModel(
        query: 'test',
        category: '의류',
        minPrice: 10000,
        sortBy: SortBy.priceLowToHigh,
      );

      final cleared = filter.clearFilters();

      expect(cleared.query, equals('test'));
      expect(cleared.sortBy, equals(SortBy.priceLowToHigh));
      expect(cleared.category, isNull);
      expect(cleared.minPrice, isNull);
      expect(cleared.hasFilters, isFalse);
    });

    test('should copyWith correctly', () {
      final filter = SearchFilterModel(
        query: 'test',
        category: '의류',
      );

      final updated = filter.copyWith(
        minPrice: 10000,
        maxPrice: 50000,
      );

      expect(updated.query, equals('test'));
      expect(updated.category, equals('의류'));
      expect(updated.minPrice, equals(10000));
      expect(updated.maxPrice, equals(50000));
    });

    test('should convert to and from JSON', () {
      final filter = SearchFilterModel(
        query: 'test',
        category: '의류',
        minPrice: 10000,
        maxPrice: 50000,
        condition: ProductCondition.likeNew,
        sortBy: SortBy.priceLowToHigh,
        selectedTags: {'tag1', 'tag2'},
      );

      final json = filter.toJson();
      final restored = SearchFilterModel.fromJson(json);

      expect(restored.query, equals(filter.query));
      expect(restored.category, equals(filter.category));
      expect(restored.minPrice, equals(filter.minPrice));
      expect(restored.maxPrice, equals(filter.maxPrice));
      expect(restored.condition, equals(filter.condition));
      expect(restored.sortBy, equals(filter.sortBy));
      expect(restored.selectedTags, equals(filter.selectedTags));
    });
  });

  group('SortBy', () {
    test('should have correct display names', () {
      expect(SortBy.newest.displayName, equals('최신순'));
      expect(SortBy.priceLowToHigh.displayName, equals('가격 낮은순'));
    });

    test('should have correct order columns', () {
      expect(SortBy.newest.orderByColumn, equals('created_at'));
      expect(SortBy.priceLowToHigh.orderByColumn, equals('price'));
    });

    test('should have correct ascending flags', () {
      expect(SortBy.newest.isAscending, isFalse);
      expect(SortBy.priceLowToHigh.isAscending, isTrue);
      expect(SortBy.priceHighToLow.isAscending, isFalse);
    });
  });

  group('SearchHistoryEntry', () {
    test('should convert to and from JSON', () {
      final now = DateTime.now();
      final entry = SearchHistoryEntry(
        query: 'test query',
        timestamp: now,
      );

      final json = entry.toJson();
      final restored = SearchHistoryEntry.fromJson(json);

      expect(restored.query, equals(entry.query));
      expect(
        restored.timestamp.difference(entry.timestamp).inSeconds,
        equals(0),
      );
    });
  });

  group('SavedSearch', () {
    test('should convert to and from JSON', () {
      final filter = SearchFilterModel(
        query: 'test',
        category: '의류',
        minPrice: 10000,
      );

      final savedSearch = SavedSearch(
        id: '123',
        name: 'My Search',
        filter: filter,
        createdAt: DateTime.now(),
        notificationsEnabled: true,
      );

      final json = savedSearch.toJson();
      final restored = SavedSearch.fromJson(json);

      expect(restored.id, equals(savedSearch.id));
      expect(restored.name, equals(savedSearch.name));
      expect(restored.notificationsEnabled, equals(savedSearch.notificationsEnabled));
      expect(restored.filter.query, equals(filter.query));
      expect(restored.filter.category, equals(filter.category));
    });
  });
}
