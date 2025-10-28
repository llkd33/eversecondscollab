# Performance Optimization - Next Steps

## ✅ Step 1: Indexes Created
You've successfully created the database indexes. Good job!

## 🔍 Step 2: Verify Indexes Are Working

Run this in Supabase SQL Editor to confirm indexes are being used:

```sql
-- Check all created indexes
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('products', 'transactions', 'messages', 'chats')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Test if indexes are actually being used (should see "Index Scan" not "Seq Scan")
EXPLAIN ANALYZE
SELECT * FROM products
WHERE seller_id = (SELECT id FROM auth.users LIMIT 1)
ORDER BY created_at DESC
LIMIT 20;
```

**Expected Result**: You should see "Index Scan" in the EXPLAIN output, not "Seq Scan".

## 🚨 Step 3: Fix N+1 Query Problem (CRITICAL)

The **biggest** performance issue is in your Flutter code, not the database. You have N+1 queries in:

### Problem Files:
1. **`lib/services/chat_service.dart`** (lines ~124-147)
2. **`lib/services/product_service.dart`** (various locations)

### What's Happening:
```dart
// ❌ BAD: This creates 1 + N queries
Future<List<Chat>> getUserChats(String userId) async {
  final chats = await _client.from('chats').select();  // 1 query

  for (var chat in chats) {
    // N additional queries! (if you have 10 chats = 10 more queries)
    final lastMessage = await getLastMessage(chat['id']);
    final unreadCount = await getUnreadCount(chat['id']);
  }
}
```

**Result**: 10 chats = 1 + 10 + 10 = **21 queries** 😱

### Solution:
Use Supabase's JOIN feature to get everything in ONE query.

## 📝 Step 4: Implement Query Optimization

### Option A: Use the RPC Function (Recommended)

You already have `get_user_chats()` RPC function! Use it instead:

**File**: `lib/services/chat_service.dart`

```dart
// ✅ GOOD: Use the RPC function that does JOINs on the database side
Future<List<Chat>> getUserChats(String userId) async {
  final response = await _client.rpc('get_user_chats', params: {
    'p_user_id': userId,
  });

  return (response as List).map((data) => Chat.fromJson(data)).toList();
}
```

**Benefits**:
- ✅ Single database query
- ✅ All JOINs happen on server side
- ✅ 95% faster than N+1 queries

### Option B: Use Supabase JOIN Syntax

If you want to keep it in Dart:

```dart
Future<List<Chat>> getUserChats(String userId) async {
  final response = await _client
      .from('chats')
      .select('''
        *,
        product:products(id, title, price, images, status),
        messages(id, content, created_at, sender_id)
      ''')
      .contains('participants', [userId])
      .order('updated_at', ascending: false);

  return response.map((data) {
    // Process the joined data
    final messages = data['messages'] as List?;
    final lastMessage = messages?.isNotEmpty == true
        ? Message.fromJson(messages!.first)
        : null;

    return Chat(
      id: data['id'],
      productId: data['product_id'],
      participants: List<String>.from(data['participants']),
      lastMessage: lastMessage,
      product: data['product'] != null ? Product.fromJson(data['product']) : null,
      // ... other fields
    );
  }).toList();
}
```

## 📊 Step 5: Measure Performance Improvement

Add performance logging to see the difference:

```dart
import 'package:logger/logger.dart';

final _logger = Logger();

Future<List<Chat>> getUserChats(String userId) async {
  final stopwatch = Stopwatch()..start();

  try {
    final response = await _client.rpc('get_user_chats', params: {
      'p_user_id': userId,
    });

    stopwatch.stop();
    _logger.i('getUserChats took ${stopwatch.elapsedMilliseconds}ms');

    return (response as List).map((data) => Chat.fromJson(data)).toList();
  } catch (e) {
    stopwatch.stop();
    _logger.e('getUserChats failed after ${stopwatch.elapsedMilliseconds}ms: $e');
    rethrow;
  }
}
```

## 🎯 Expected Results

### Before Optimization:
- 10 chats = **21 queries**
- Load time: **~2.5 seconds**
- Data transfer: **~150KB**

### After Optimization:
- 10 chats = **1 query**
- Load time: **~0.3 seconds** (88% faster ⚡)
- Data transfer: **~80KB** (47% less)

## 📋 Action Items Checklist

- [x] Create database indexes (DONE!)
- [ ] Verify indexes with EXPLAIN ANALYZE
- [ ] Update `chat_service.dart` to use `get_user_chats()` RPC
- [ ] Update `product_service.dart` to use JOINs
- [ ] Add performance logging
- [ ] Test and measure improvements
- [ ] Remove old N+1 query code

## 🔧 Files to Update

1. **`lib/services/chat_service.dart`**
   - Replace `getUserChats()` with RPC call
   - Remove individual `getLastMessage()` and `getUnreadCount()` calls in loops

2. **`lib/services/product_service.dart`**
   - Add seller info to SELECT with JOIN
   - Use `.select('*, seller:users!seller_id(id, name, profile_image_url)')`

## 💡 Pro Tips

1. **Always use JOINs** instead of loops with queries
2. **Use RPC functions** for complex queries
3. **Measure everything** with stopwatch logging
4. **Check EXPLAIN ANALYZE** when in doubt
5. **Limit results** with `.limit()` for large datasets

## 🆘 Need Help?

If you encounter issues, check:
1. RPC function exists: `SELECT * FROM pg_proc WHERE proname = 'get_user_chats';`
2. Indexes are active: Run the verification query above
3. Logs show errors: Check Supabase Dashboard → Logs

---

**Ready to optimize?** Start with updating `chat_service.dart` first - that's where you'll see the biggest impact!
