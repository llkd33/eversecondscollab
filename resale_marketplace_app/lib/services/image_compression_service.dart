import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 이미지 압축 서비스
/// 이미지 크기와 용량을 최적화하여 업로드 성능과 저장공간을 개선
class ImageCompressionService {
  static const int _maxFileSize = 2 * 1024 * 1024; // 2MB
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;
  static const int _defaultQuality = 85;
  static const int _thumbnailSize = 300;

  /// 이미지 압축 (메인 이미지용)
  static Future<File?> compressImage(
    File imageFile, {
    int maxWidth = _maxWidth,
    int maxHeight = _maxHeight,
    int quality = _defaultQuality,
    int maxFileSize = _maxFileSize,
  }) async {
    try {
      // 원본 파일 크기 확인
      final originalSize = await imageFile.length();
      print('📸 원본 이미지 크기: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 임시 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basenameWithoutExtension(imageFile.path);
      final extension = path.extension(imageFile.path).toLowerCase();
      
      // 지원하는 형식 확인
      final supportedFormats = ['.jpg', '.jpeg', '.png', '.webp'];
      if (!supportedFormats.contains(extension)) {
        throw Exception('지원하지 않는 이미지 형식입니다: $extension');
      }

      final compressedPath = path.join(
        tempDir.path,
        '${fileName}_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // 압축 실행
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        compressedPath,
        quality: quality,
        minWidth: 200,
        minHeight: 200,
        format: CompressFormat.jpeg,
        keepExif: false, // EXIF 데이터 제거로 용량 절약
      );

      if (compressedFile == null) {
        print('⚠️ 이미지 압축 실패, 원본 파일 사용');
        return imageFile;
      }

      final compressedSize = await compressedFile.length();
      print('📸 압축된 이미지 크기: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');
      print('📈 압축률: ${((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1)}%');

      // 압축 후에도 크기가 큰 경우 품질을 더 낮춰서 재압축
      if (compressedSize > maxFileSize && quality > 50) {
        print('🔄 파일 크기가 여전히 큰 관계로 재압축 시도...');
        final secondCompression = await _recompressWithLowerQuality(
          File(compressedFile.path),
          maxFileSize: maxFileSize,
          initialQuality: quality - 20,
        );
        
        if (secondCompression != null) {
          // 첫 번째 압축 파일 삭제
          try {
            final file = File(compressedFile.path);
            await file.delete();
          } catch (e) {
            print('임시 파일 삭제 실패: $e');
          }
          return secondCompression;
        }
      }

      return File(compressedFile.path);
    } catch (e) {
      print('❌ 이미지 압축 중 오류 발생: $e');
      return imageFile; // 압축 실패 시 원본 반환
    }
  }

  /// 썸네일 생성
  static Future<File?> createThumbnail(
    File imageFile, {
    int size = _thumbnailSize,
    int quality = 75,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basenameWithoutExtension(imageFile.path);
      
      final thumbnailPath = path.join(
        tempDir.path,
        '${fileName}_thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final thumbnailFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        thumbnailPath,
        quality: quality,
        minWidth: 100,
        minHeight: 100,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (thumbnailFile != null) {
        final thumbnailSize = await thumbnailFile.length();
        print('🖼️ 썸네일 생성 완료: ${(thumbnailSize / 1024).toStringAsFixed(1)}KB');
        return File(thumbnailFile.path);
      }

      return null;
    } catch (e) {
      print('❌ 썸네일 생성 중 오류 발생: $e');
      return null;
    }
  }

  /// 여러 이미지 배치 압축
  static Future<List<File>> compressImages(
    List<File> imageFiles, {
    int maxWidth = _maxWidth,
    int maxHeight = _maxHeight,
    int quality = _defaultQuality,
    int maxFileSize = _maxFileSize,
    Function(int current, int total)? onProgress,
  }) async {
    final compressedFiles = <File>[];
    
    for (int i = 0; i < imageFiles.length; i++) {
      onProgress?.call(i + 1, imageFiles.length);
      
      final compressedFile = await compressImage(
        imageFiles[i],
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
        maxFileSize: maxFileSize,
      );
      
      if (compressedFile != null) {
        compressedFiles.add(compressedFile);
      }
    }
    
    return compressedFiles;
  }

  /// 메모리에서 이미지 압축 (바이트 배열)
  static Future<Uint8List?> compressImageBytes(
    Uint8List imageBytes, {
    int maxWidth = _maxWidth,
    int maxHeight = _maxHeight,
    int quality = _defaultQuality,
  }) async {
    try {
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: quality,
        minWidth: 200,
        minHeight: 200,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      final originalSize = imageBytes.length;
      final compressedSize = compressedBytes.length;
      
      print('📸 바이트 압축 완료');
      print('📏 원본: ${(originalSize / 1024).toStringAsFixed(1)}KB');
      print('📏 압축: ${(compressedSize / 1024).toStringAsFixed(1)}KB');
      print('📈 압축률: ${((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1)}%');

      return compressedBytes;
    } catch (e) {
      print('❌ 바이트 이미지 압축 중 오류 발생: $e');
      return imageBytes; // 압축 실패 시 원본 반환
    }
  }

  /// 품질을 낮춰서 재압축
  static Future<File?> _recompressWithLowerQuality(
    File imageFile, {
    required int maxFileSize,
    int initialQuality = 60,
  }) async {
    int quality = initialQuality;
    File? result;

    while (quality >= 30) {
      try {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basenameWithoutExtension(imageFile.path);
        
        final recompressedPath = path.join(
          tempDir.path,
          '${fileName}_recompressed_q${quality}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        final recompressedFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          recompressedPath,
          quality: quality,
          minWidth: 200,
          minHeight: 200,
          format: CompressFormat.jpeg,
          keepExif: false,
        );

        if (recompressedFile != null) {
          final size = await recompressedFile.length();
          print('🔄 품질 $quality%로 재압축: ${(size / 1024 / 1024).toStringAsFixed(2)}MB');
          
          if (size <= maxFileSize) {
            result = File(recompressedFile.path);
            break;
          }
        }

        quality -= 10;
      } catch (e) {
        print('❌ 재압축 중 오류 (품질 $quality%): $e');
        quality -= 10;
      }
    }

    return result;
  }

  /// 이미지 압축 설정 클래스
  static ImageCompressionConfig getConfigForType(ImageType type) {
    switch (type) {
      case ImageType.product:
        return ImageCompressionConfig(
          maxWidth: 1920,
          maxHeight: 1920,
          quality: 85,
          maxFileSize: 2 * 1024 * 1024, // 2MB
        );
      case ImageType.profile:
        return ImageCompressionConfig(
          maxWidth: 800,
          maxHeight: 800,
          quality: 90,
          maxFileSize: 1 * 1024 * 1024, // 1MB
        );
      case ImageType.chat:
        return ImageCompressionConfig(
          maxWidth: 1280,
          maxHeight: 1280,
          quality: 80,
          maxFileSize: (1.5 * 1024 * 1024).round(), // 1.5MB
        );
      case ImageType.thumbnail:
        return ImageCompressionConfig(
          maxWidth: 300,
          maxHeight: 300,
          quality: 75,
          maxFileSize: 100 * 1024, // 100KB
        );
    }
  }

  /// 임시 파일 정리
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync();
      
      for (final file in tempFiles) {
        if (file is File && 
            (file.path.contains('compressed') || 
             file.path.contains('thumbnail') || 
             file.path.contains('recompressed'))) {
          try {
            await file.delete();
          } catch (e) {
            print('임시 파일 삭제 실패: ${file.path}');
          }
        }
      }
      
      print('🧹 임시 파일 정리 완료');
    } catch (e) {
      print('❌ 임시 파일 정리 중 오류: $e');
    }
  }
}

/// 이미지 타입별 압축 설정
enum ImageType {
  product,
  profile,
  chat,
  thumbnail,
}

/// 이미지 압축 설정
class ImageCompressionConfig {
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final int maxFileSize;

  const ImageCompressionConfig({
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
    required this.maxFileSize,
  });
}