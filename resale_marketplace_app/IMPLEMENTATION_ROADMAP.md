# 🗺️ 구현 로드맵

## 📚 가이드 문서 목록

이 프로젝트를 위해 다음 가이드 문서들이 작성되었습니다:

1. **SECURITY_GUIDE.md** - 보안 개선 가이드
2. **PERFORMANCE_GUIDE.md** - 성능 최적화 가이드
3. **ARCHITECTURE_GUIDE.md** - 아키텍처 개선 가이드
4. **QUALITY_GUIDE.md** - 코드 품질 개선 가이드
5. **FEATURES_GUIDE.md** - 기능 개선 가이드

## 🎯 구현 우선순위

### 🚨 Critical (1-2주) - 즉시 시작 필요

#### Week 1: 보안 & 데이터베이스
- **Day 1-2**: 보안 개선
  - [ ] Supabase API 키 재발급
  - [ ] Kakao API 키 재발급
  - [ ] 환경변수 설정 (.env 파일)
  - [ ] .gitignore 업데이트
  - [ ] 하드코딩된 키 제거
  - 📖 참조: **SECURITY_GUIDE.md**

- **Day 3-4**: 데이터베이스 최적화
  - [ ] 인덱스 추가 (Products, Transactions, Messages, Chats)
  - [ ] 인덱스 성능 확인 (EXPLAIN ANALYZE)
  - 📖 참조: **PERFORMANCE_GUIDE.md** Step 1

- **Day 5-7**: N+1 쿼리 최적화
  - [ ] ChatService 최적화 (JOIN 사용)
  - [ ] ProductService 최적화
  - [ ] RPC 함수 생성 (get_unread_counts)
  - [ ] 성능 측정 및 비교
  - 📖 참조: **PERFORMANCE_GUIDE.md** Step 2-3

#### Week 2: 디버그 코드 제거
- **Day 8-9**: 디버그 인증 우회 제거
  - [ ] `lib/providers/auth_provider.dart:19` 수정
  - [ ] `@visibleForTesting` 어노테이션 추가
  - [ ] assert 블록으로 감싸기
  - [ ] 프로덕션 빌드 테스트
  - 📖 참조: **SECURITY_GUIDE.md**

### ⚠️ High (3-4주) - 다음 단계

#### Week 3-4: 아키텍처 & 품질

- **Day 1-5**: 의존성 주입 패턴
  - [ ] 서비스 인터페이스 정의 (IProductService, IChatService 등)
  - [ ] 서비스 구현체 리팩토링
  - [ ] get_it 패키지 추가
  - [ ] Service Locator 설정
  - [ ] Provider와 통합
  - 📖 참조: **ARCHITECTURE_GUIDE.md**

- **Day 6-8**: 입력 검증 & 에러 처리
  - [ ] Validators 유틸리티 생성
  - [ ] Result 패턴 구현
  - [ ] 모든 Form에 검증 로직 적용
  - [ ] 서비스에 Result 패턴 적용
  - [ ] 에러 UI 개선
  - 📖 참조: **QUALITY_GUIDE.md**

- **Day 9-12**: 이미지 압축 & 유틸리티
  - [ ] ImageCompressionService 생성
  - [ ] 상품 등록 시 이미지 압축 적용
  - [ ] Formatters 유틸리티 생성
  - [ ] ImageUtils 유틸리티 생성
  - [ ] 중복 코드 제거
  - 📖 참조: **FEATURES_GUIDE.md**, **QUALITY_GUIDE.md**

### 📋 Medium (5-8주) - 장기 개선

#### Week 5-6: 레이어 아키텍처

- [ ] 디렉토리 구조 재구성
  - core/, domain/, data/, presentation/ 분리
- [ ] Use Case 레이어 추가
- [ ] Repository 패턴 도입
- [ ] 단위 테스트 작성
- 📖 참조: **ARCHITECTURE_GUIDE.md**

#### Week 7: 캐싱 & 페이지네이션

- [ ] MemoryCache 구현
- [ ] 서비스에 캐싱 로직 적용
- [ ] PaginationState 구현
- [ ] 무한 스크롤 UI 적용
- [ ] Pull-to-refresh 기능
- 📖 참조: **FEATURES_GUIDE.md**

#### Week 8: 테스트 & 문서화

- [ ] Mock 객체 생성
- [ ] Provider 단위 테스트
- [ ] Service 단위 테스트
- [ ] 통합 테스트
- [ ] API 문서 작성
- 📖 참조: **ARCHITECTURE_GUIDE.md**

## 📊 각 단계별 예상 효과

### Critical 완료 후
- ✅ **보안**: API 키 노출 위험 제거
- ✅ **성능**: 채팅 로딩 2.5초 → 0.3초 (88% 개선)
- ✅ **성능**: 상품 로딩 1.8초 → 0.2초 (89% 개선)
- ✅ **데이터베이스**: 쿼리 수 90% 감소

### High 완료 후
- ✅ **코드 품질**: 테스트 가능한 구조
- ✅ **보안**: XSS, SQL Injection 방어
- ✅ **사용성**: 명확한 에러 메시지
- ✅ **성능**: 이미지 데이터 70% 감소

### Medium 완료 후
- ✅ **유지보수성**: 명확한 아키텍처
- ✅ **확장성**: 새 기능 추가 용이
- ✅ **성능**: API 호출 50% 감소
- ✅ **품질**: 테스트 커버리지 80%+

## 🔄 구현 플로우

```
Week 1-2 (Critical)
└─ 보안 개선 → DB 최적화 → N+1 쿼리 해결
   └─ 즉시 체감 가능한 성능 개선

Week 3-4 (High)
└─ 아키텍처 개선 → 품질 개선 → 기능 추가
   └─ 코드 품질 및 사용성 개선

Week 5-8 (Medium)
└─ 레이어 분리 → 캐싱 → 테스트
   └─ 장기적 유지보수성 확보
```

## 📝 구현 시 주의사항

### 1. 순차적 진행
- 각 단계는 이전 단계 완료 후 진행
- 특히 Critical → High → Medium 순서 유지

### 2. 테스트 필수
- 각 기능 구현 후 반드시 테스트
- 프로덕션 배포 전 충분한 QA

### 3. 백업 및 롤백 계획
- 변경 전 현재 코드 백업
- Git 브랜치 전략 사용 (feature/*, fix/*)
- 문제 발생 시 롤백 가능하도록 준비

### 4. 문서화
- 변경 사항 CHANGELOG 기록
- API 변경 시 문서 업데이트
- 팀원과 공유

## 🚀 시작하기

### Option 1: 단계별 직접 구현
각 가이드 문서를 참고하여 직접 구현합니다.

```bash
# 1. 보안 개선부터 시작
cat SECURITY_GUIDE.md

# 2. 환경변수 설정
cp .env.example .env
# .env 파일 편집하여 새로운 API 키 입력

# 3. 코드 수정 시작
# lib/config/supabase_config.dart 수정
# lib/config/kakao_config.dart 수정
```

### Option 2: 우선순위 높은 것부터 함께 구현
더 빠른 구현을 원하신다면, 다음과 같이 요청하세요:

```
"Week 1 Critical 항목들을 함께 구현하자"
또는
"보안 개선부터 시작해서 하나씩 함께 진행하자"
```

### Option 3: 특정 부분만 선택
특정 개선사항만 원하신다면:

```
"이미지 압축 기능만 먼저 구현하자"
또는
"페이지네이션만 추가하자"
```

## 📞 도움이 필요할 때

각 가이드 문서에는 상세한 코드 예시와 설명이 포함되어 있습니다.

- **보안 관련**: SECURITY_GUIDE.md
- **성능 관련**: PERFORMANCE_GUIDE.md
- **아키텍처 관련**: ARCHITECTURE_GUIDE.md
- **코드 품질**: QUALITY_GUIDE.md
- **새 기능**: FEATURES_GUIDE.md

막히는 부분이 있다면 언제든 질문해주세요!

## ✅ 전체 체크리스트

### Critical (1-2주)
- [ ] API 키 재발급 및 환경변수 이전
- [ ] 디버그 인증 우회 제거
- [ ] 데이터베이스 인덱스 16개 추가
- [ ] N+1 쿼리 최적화 (ChatService, ProductService)
- [ ] RPC 함수 생성

### High (3-4주)
- [ ] 의존성 주입 패턴 (5일)
- [ ] 입력 검증 강화 (3일)
- [ ] 에러 처리 통일 (3일)
- [ ] 이미지 압축 구현 (2일)
- [ ] 중복 코드 제거 (2일)

### Medium (5-8주)
- [ ] 레이어 아키텍처 재구성 (10일)
- [ ] 캐싱 전략 구현 (3일)
- [ ] 페이지네이션 적용 (2일)
- [ ] 단위 테스트 작성 (7일)

## 🎉 완료 후 기대 효과

### 성능
- 로딩 속도: **5-10배 개선**
- API 호출: **70-90% 감소**
- 데이터 사용량: **70% 절감**

### 보안
- API 키 노출: **완전 제거**
- 입력 검증: **XSS/SQL Injection 방어**
- 디버그 우회: **프로덕션 제거**

### 코드 품질
- 테스트 커버리지: **80%+**
- 유지보수성: **명확한 아키텍처**
- 확장성: **새 기능 추가 용이**

---

**다음 단계**: 어떤 방식으로 진행하시겠습니까?

1. 직접 구현 (가이드 참고)
2. 함께 단계별 구현
3. 특정 부분만 선택 구현

선택하신 후 시작하시면 됩니다! 🚀
