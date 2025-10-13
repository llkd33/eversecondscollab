import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/review_model.dart';
import '../utils/uuid.dart';
import 'image_compression_service.dart';

class ReviewService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 리뷰 작성
  Future<ReviewModel?> createReview({
    required String reviewerId,
    required String reviewedUserId,
    required String transactionId,
    required int rating,
    required String content,
    List<String>? tags,
    List<String>? images,
  }) async {
    try {
      if (!UuidUtils.isValid(reviewerId) ||
          !UuidUtils.isValid(reviewedUserId) ||
          !UuidUtils.isValid(transactionId)) {
        throw Exception('리뷰 작성에 필요한 식별자가 올바르지 않습니다.');
      }
      // 중복 리뷰 확인
      final existingReview = await _client
          .from('reviews')
          .select('id')
          .eq('reviewer_id', reviewerId)
          .eq('reviewed_user_id', reviewedUserId)
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (existingReview != null) {
        throw Exception('이미 해당 거래에 대한 리뷰를 작성하셨습니다.');
      }

      final response = await _client
          .from('reviews')
          .insert({
            'reviewer_id': reviewerId,
            'reviewed_user_id': reviewedUserId,
            'transaction_id': transactionId,
            'rating': rating,
            'comment': content,
            'tags': tags ?? [],
            'images': images ?? [],
          })
          .select()
          .single();

      return ReviewModel.fromJson(response);
    } catch (e) {
      print('Error creating review: $e');
      return null;
    }
  }

  // 리뷰 ID로 조회
  Future<ReviewModel?> getReviewById(String reviewId) async {
    try {
      // Avoid 22P02 on invalid ids
      if (!UuidUtils.isValid(reviewId)) {
        print('getReviewById skipped: invalid UUID "$reviewId"');
        return null;
      }
      final response = await _client
          .from('reviews')
          .select('''
            *,
            reviewer:users!reviewer_id (name, profile_image),
            reviewed_user:users!reviewed_user_id (name, profile_image),
            transactions!transaction_id (
              products!product_id (title)
            )
          ''')
          .eq('id', reviewId)
          .single();

      final review = ReviewModel.fromJson(response);

      // 조인된 정보 매핑
      final reviewer = response['reviewer'];
      final reviewedUser = response['reviewed_user'];
      final transaction = response['transactions'];

      return review.copyWith(
        reviewerName: reviewer?['name'],
        reviewerImage: reviewer?['profile_image'],
        reviewedUserName: reviewedUser?['name'],
        reviewedUserImage: reviewedUser?['profile_image'],
        productTitle: transaction?['products']?['title'],
      );
    } catch (e) {
      print('Error getting review by id: $e');
      return null;
    }
  }

  // 사용자가 받은 리뷰 목록 조회
  Future<List<ReviewModel>> getReceivedReviews({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('reviews')
          .select('''
            *,
            reviewer:users!reviewer_id (name, profile_image),
            reviewed_user:users!reviewed_user_id (name, profile_image),
            transactions!transaction_id (
              products!product_id (title)
            )
          ''')
          .eq('reviewed_user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((item) {
        final review = ReviewModel.fromJson(item);

        // 조인된 정보 매핑
        final reviewer = item['reviewer'];
        final reviewedUser = item['reviewed_user'];
        final transaction = item['transactions'];

        return review.copyWith(
          reviewerName: reviewer?['name'],
          reviewerImage: reviewer?['profile_image'],
          reviewedUserName: reviewedUser?['name'],
          reviewedUserImage: reviewedUser?['profile_image'],
          productTitle: transaction?['products']?['title'],
        );
      }).toList();
    } catch (e) {
      print('Error getting received reviews: $e');
      return [];
    }
  }

  // 사용자가 작성한 리뷰 목록 조회
  Future<List<ReviewModel>> getWrittenReviews({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('reviews')
          .select('''
            *,
            reviewer:users!reviewer_id (name, profile_image),
            reviewed_user:users!reviewed_user_id (name, profile_image),
            transactions!transaction_id (
              products!product_id (title)
            )
          ''')
          .eq('reviewer_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((item) {
        final review = ReviewModel.fromJson(item);

        // 조인된 정보 매핑
        final reviewer = item['reviewer'];
        final reviewedUser = item['reviewed_user'];
        final transaction = item['transactions'];

        return review.copyWith(
          reviewerName: reviewer?['name'],
          reviewerImage: reviewer?['profile_image'],
          reviewedUserName: reviewedUser?['name'],
          reviewedUserImage: reviewedUser?['profile_image'],
          productTitle: transaction?['products']?['title'],
        );
      }).toList();
    } catch (e) {
      print('Error getting written reviews: $e');
      return [];
    }
  }

  // 거래별 리뷰 조회
  Future<List<ReviewModel>> getTransactionReviews(String transactionId) async {
    try {
      if (!UuidUtils.isValid(transactionId)) {
        print('getTransactionReviews skipped: invalid UUID "$transactionId"');
        return [];
      }
      final response = await _client
          .from('reviews')
          .select('''
            *,
            reviewer:users!reviewer_id (name, profile_image),
            reviewed_user:users!reviewed_user_id (name, profile_image),
            transactions!transaction_id (
              products!product_id (title)
            )
          ''')
          .eq('transaction_id', transactionId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final review = ReviewModel.fromJson(item);

        // 조인된 정보 매핑
        final reviewer = item['reviewer'];
        final reviewedUser = item['reviewed_user'];
        final transaction = item['transactions'];

        return review.copyWith(
          reviewerName: reviewer?['name'],
          reviewerImage: reviewer?['profile_image'],
          reviewedUserName: reviewedUser?['name'],
          reviewedUserImage: reviewedUser?['profile_image'],
          productTitle: transaction?['products']?['title'],
        );
      }).toList();
    } catch (e) {
      print('Error getting transaction reviews: $e');
      return [];
    }
  }

  // 리뷰 수정
  Future<bool> updateReview({
    required String reviewId,
    int? rating,
    String? comment,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (rating != null) updates['rating'] = rating;
      if (comment != null) updates['comment'] = comment;

      if (updates.isEmpty) return true;

      await _client.from('reviews').update(updates).eq('id', reviewId);

      return true;
    } catch (e) {
      print('Error updating review: $e');
      return false;
    }
  }

  // 리뷰 삭제
  Future<bool> deleteReview(String reviewId) async {
    try {
      await _client.from('reviews').delete().eq('id', reviewId);

      return true;
    } catch (e) {
      print('Error deleting review: $e');
      return false;
    }
  }

  // 리뷰 이미지 업로드
  Future<List<String>> uploadReviewImages(
    List<File> imageFiles,
    String userId,
  ) async {
    final uploadedUrls = <String>[];

    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final originalFile = imageFiles[i];
        print('📷 리뷰 이미지 업로드 시작 ($i/${imageFiles.length})');
        
        // 리뷰 이미지 압축
        final compressedFile = await ImageCompressionService.compressImage(
          originalFile,
          maxWidth: 1280,
          maxHeight: 1280,
          quality: 85,
          maxFileSize: (1.5 * 1024 * 1024).round(), // 1.5MB
        );
        
        if (compressedFile == null) {
          print('⚠️ 리뷰 이미지 압축 실패, 건너뛰기...');
          continue;
        }
        
        final fileName = 'review_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final bytes = await compressedFile.readAsBytes();
        
        print('📦 압축된 리뷰 이미지 업로드: ${(bytes.length / 1024).toStringAsFixed(1)}KB');

        await _client.storage
            .from('review-images')
            .uploadBinary(fileName, bytes);

        final url = _client.storage
            .from('review-images')
            .getPublicUrl(fileName);

        uploadedUrls.add(url);
        
        // 임시 압축 파일 삭제
        if (compressedFile.path != originalFile.path) {
          try {
            await compressedFile.delete();
          } catch (e) {
            print('임시 파일 삭제 실패: $e');
          }
        }
      }

      return uploadedUrls;
    } catch (e) {
      print('Error uploading review images: $e');
      // 실패한 경우 이미 업로드된 이미지 삭제
      for (final url in uploadedUrls) {
        final fileName = url.split('/').last;
        await deleteReviewImage(fileName);
      }
      return [];
    }
  }

  // 리뷰 이미지 삭제
  Future<bool> deleteReviewImage(String fileName) async {
    try {
      await _client.storage.from('review-images').remove([fileName]);

      return true;
    } catch (e) {
      print('Error deleting review image: $e');
      return false;
    }
  }

  // 사용자 평점 통계 조회
  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    try {
      final response = await _client
          .from('reviews')
          .select('rating')
          .eq('reviewed_user_id', userId);

      if (response.isEmpty) {
        return {
          'average_rating': 0.0,
          'total_reviews': 0,
          'rating_distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        };
      }

      final ratings = response.map((r) => r['rating'] as int).toList();
      final totalReviews = ratings.length;
      final averageRating = ratings.reduce((a, b) => a + b) / totalReviews;

      // 별점별 분포
      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final rating in ratings) {
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }

      return {
        'average_rating': double.parse(averageRating.toStringAsFixed(1)),
        'total_reviews': totalReviews,
        'rating_distribution': distribution,
      };
    } catch (e) {
      print('Error getting user rating stats: $e');
      return {
        'average_rating': 0.0,
        'total_reviews': 0,
        'rating_distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }
  }

  // 거래에서 리뷰 작성 가능한 상대방 목록 조회
  Future<List<Map<String, dynamic>>> getReviewableUsers({
    required String transactionId,
    required String currentUserId,
  }) async {
    try {
      // 거래 정보 조회
      final transactionResponse = await _client
          .from('transactions')
          .select('''
            *,
            buyer:users!buyer_id (id, name, profile_image),
            seller:users!seller_id (id, name, profile_image),
            reseller:users!reseller_id (id, name, profile_image)
          ''')
          .eq('id', transactionId)
          .single();

      final reviewableUsers = <Map<String, dynamic>>[];

      final buyerId = transactionResponse['buyer_id'];
      final sellerId = transactionResponse['seller_id'];
      final resellerId = transactionResponse['reseller_id'];

      final buyer = transactionResponse['buyer'];
      final seller = transactionResponse['seller'];
      final reseller = transactionResponse['reseller'];

      // 현재 사용자가 구매자인 경우
      if (currentUserId == buyerId) {
        // 판매자에게 리뷰 가능
        if (seller != null) {
          reviewableUsers.add({
            'user_id': sellerId,
            'name': seller['name'],
            'profile_image': seller['profile_image'],
            'role': '판매자',
          });
        }
        // 대신판매자에게 리뷰 가능
        if (reseller != null) {
          reviewableUsers.add({
            'user_id': resellerId,
            'name': reseller['name'],
            'profile_image': reseller['profile_image'],
            'role': '대신판매자',
          });
        }
      }

      // 현재 사용자가 판매자인 경우
      if (currentUserId == sellerId) {
        // 구매자에게 리뷰 가능
        if (buyer != null) {
          reviewableUsers.add({
            'user_id': buyerId,
            'name': buyer['name'],
            'profile_image': buyer['profile_image'],
            'role': '구매자',
          });
        }
        // 대신판매자에게 리뷰 가능 (대신팔기 거래인 경우)
        if (reseller != null) {
          reviewableUsers.add({
            'user_id': resellerId,
            'name': reseller['name'],
            'profile_image': reseller['profile_image'],
            'role': '대신판매자',
          });
        }
      }

      // 현재 사용자가 대신판매자인 경우
      if (currentUserId == resellerId) {
        // 구매자에게 리뷰 가능
        if (buyer != null) {
          reviewableUsers.add({
            'user_id': buyerId,
            'name': buyer['name'],
            'profile_image': buyer['profile_image'],
            'role': '구매자',
          });
        }
        // 원 판매자에게 리뷰 가능
        if (seller != null) {
          reviewableUsers.add({
            'user_id': sellerId,
            'name': seller['name'],
            'profile_image': seller['profile_image'],
            'role': '원판매자',
          });
        }
      }

      // 이미 작성한 리뷰 제외
      for (final user in reviewableUsers) {
        final existingReview = await _client
            .from('reviews')
            .select('id')
            .eq('reviewer_id', currentUserId)
            .eq('reviewed_user_id', user['user_id'])
            .eq('transaction_id', transactionId)
            .maybeSingle();

        user['already_reviewed'] = existingReview != null;
      }

      return reviewableUsers;
    } catch (e) {
      print('Error getting reviewable users: $e');
      return [];
    }
  }

  // 최근 리뷰 목록 조회 (홈화면용)
  Future<List<ReviewModel>> getRecentReviews({int limit = 10}) async {
    try {
      final response = await _client
          .from('reviews')
          .select('''
            *,
            reviewer:users!reviewer_id (name, profile_image),
            reviewed_user:users!reviewed_user_id (name, profile_image),
            transactions!transaction_id (
              products!product_id (title, images)
            )
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((item) {
        final review = ReviewModel.fromJson(item);

        // 조인된 정보 매핑
        final reviewer = item['reviewer'];
        final reviewedUser = item['reviewed_user'];
        final transaction = item['transactions'];

        return review.copyWith(
          reviewerName: reviewer?['name'],
          reviewerImage: reviewer?['profile_image'],
          reviewedUserName: reviewedUser?['name'],
          reviewedUserImage: reviewedUser?['profile_image'],
          productTitle: transaction?['products']?['title'],
        );
      }).toList();
    } catch (e) {
      print('Error getting recent reviews: $e');
      return [];
    }
  }
}
