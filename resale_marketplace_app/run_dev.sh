#!/bin/bash

# Development 환경으로 Flutter 앱 실행
# 사용법: ./run_dev.sh [device-id]

# .env.development 파일 로드
if [ -f .env.development ]; then
  set -a
  source .env.development
  set +a
  echo "✅ 환경변수 로드 완료"
  echo "   SUPABASE_URL: ${SUPABASE_URL:0:30}..."
  echo "   KAKAO_NATIVE_APP_KEY: ${KAKAO_NATIVE_APP_KEY:0:10}..."
else
  echo "❌ .env.development 파일이 없습니다!"
  echo "📝 .env.example을 복사하여 .env.development를 생성하세요."
  exit 1
fi

# Flutter 실행
DEVICE_ID=${1:-""}

if [ -z "$DEVICE_ID" ]; then
  echo "🚀 Flutter 앱 실행 중 (기본 디바이스)..."
  flutter run \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=KAKAO_NATIVE_APP_KEY="$KAKAO_NATIVE_APP_KEY" \
    --dart-define=KAKAO_JAVASCRIPT_KEY="$KAKAO_JAVASCRIPT_KEY" \
    --dart-define=KAKAO_REST_API_KEY="$KAKAO_REST_API_KEY"
else
  echo "🚀 Flutter 앱 실행 중 (디바이스: $DEVICE_ID)..."
  flutter run -d "$DEVICE_ID" \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=KAKAO_NATIVE_APP_KEY="$KAKAO_NATIVE_APP_KEY" \
    --dart-define=KAKAO_JAVASCRIPT_KEY="$KAKAO_JAVASCRIPT_KEY" \
    --dart-define=KAKAO_REST_API_KEY="$KAKAO_REST_API_KEY"
fi
