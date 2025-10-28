import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class ImageCompressionService {
  final Logger _logger;

  ImageCompressionService({Logger? logger}) : _logger = logger ?? Logger();

  /// 이미지 압축
  ///
  /// [file] 원본 이미지 파일
  /// [quality] 압축 품질 (0-100, 기본값: 85)
  /// [maxWidth] 최대 너비 (기본값: 1920)
  /// [maxHeight] 최대 높이 (기본값: 1920)
  Future<File?> compressImage(
    File file, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      _logger.d('이미지 압축 시작: ${file.path}');

      // 원본 파일 크기
      final originalSize = await file.length();
      _logger.d('원본 크기: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 임시 디렉토리
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      // 압축 실행
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        _logger.e('압축 실패');
        return null;
      }

      // 압축된 파일 크기
      final compressedSize = await File(compressedFile.path).length();
      final reduction = ((originalSize - compressedSize) / originalSize * 100);

      _logger.i(
        '압축 완료: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB '
        '(${reduction.toStringAsFixed(1)}% 감소)',
      );

      return File(compressedFile.path);
    } catch (e, stackTrace) {
      _logger.e('이미지 압축 실패', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 여러 이미지 압축
  Future<List<File>> compressMultipleImages(
    List<File> files, {
    int quality = 85,
  }) async {
    final compressedFiles = <File>[];

    for (final file in files) {
      final compressed = await compressImage(file, quality: quality);
      if (compressed != null) {
        compressedFiles.add(compressed);
      }
    }

    _logger.i(
      '다중 이미지 압축 완료: ${compressedFiles.length}/${files.length}',
    );

    return compressedFiles;
  }

  /// 썸네일 생성
  Future<Uint8List?> generateThumbnail(
    File file, {
    int width = 400,
    int quality = 80,
  }) async {
    try {
      _logger.d('썸네일 생성: ${file.path}');

      final thumbnail = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: width,
        minHeight: width,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (thumbnail != null) {
        _logger.i(
          '썸네일 생성 완료: ${(thumbnail.length / 1024).toStringAsFixed(2)}KB',
        );
      }

      return thumbnail;
    } catch (e, stackTrace) {
      _logger.e('썸네일 생성 실패', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 이미지 크기 가져오기 (압축 없이)
  Future<Map<String, int>?> getImageDimensions(File file) async {
    try {
      final data = await file.readAsBytes();
      final image = await decodeImageFromList(data);

      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      _logger.e('이미지 크기 조회 실패', error: e);
      return null;
    }
  }

  /// Helper: Uint8List에서 이미지 디코딩
  Future<dynamic> decodeImageFromList(Uint8List data) async {
    // Flutter의 ui.Image를 사용하여 이미지 디코딩
    // 실제 구현은 flutter/painting을 import 해야 함
    throw UnimplementedError('decodeImageFromList needs Flutter UI import');
  }
}
