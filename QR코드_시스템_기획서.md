# QR 코드 시스템 기획서

## 📱 개요

### 1.1 목적
상품과 QR 코드를 연결하여 오프라인 환경에서 빠른 상품 정보 접근 및 진위 확인 제공

### 1.2 핵심 가치
- **판매자**: 상품 등록 완료 시 QR 코드 자동 생성 및 출력
- **구매자**: 모바일로 QR 스캔하여 상품 정보 즉시 확인
- **플랫폼**: 상품 진위 확인 및 거래 추적

### 1.3 주요 기능
- 상품별 고유 QR 코드 생성
- QR 코드 스캔 및 상품 페이지 연결
- QR 코드 출력 (키오스크/모바일)
- 스캔 이력 추적 및 통계

---

## 🎯 사용 시나리오

### 2.1 판매자 시나리오

```
1. 판매자가 키오스크에서 상품 등록
   ↓
2. 상품 등록 완료 시 QR 코드 자동 생성
   ↓
3. QR 코드를 실물 상품에 부착
   - 프린터로 출력하거나
   - 휴대폰으로 받아 화면 표시
   ↓
4. 상품 전시 (QR 코드와 함께)
```

### 2.2 구매자 시나리오

```
1. 매장에서 상품 발견
   ↓
2. 스마트폰으로 QR 코드 스캔
   ↓
3. 상품 상세 페이지로 자동 이동
   - 상품 정보 확인
   - 판매자 정보 확인
   - 가격 확인
   ↓
4. 관심 있으면 판매자에게 연락
   or 찜하기
```

### 2.3 플랫폼 관리자 시나리오

```
1. QR 코드 스캔 통계 모니터링
   ↓
2. 인기 상품 / 위치 분석
   ↓
3. 가짜 QR 코드 탐지 및 차단
```

---

## 🔐 QR 코드 데이터 구조

### 3.1 QR 코드 페이로드

```typescript
interface QRCodePayload {
  // 버전 (향후 확장성)
  version: string;           // "1.0"

  // 상품 ID (Primary)
  productId: string;         // UUID

  // 판매자 ID (검증용)
  sellerId: string;          // UUID

  // 타임스탬프 (생성 시각)
  timestamp: string;         // ISO 8601

  // URL (Direct Link)
  url: string;               // "https://everseconds.com/product/{id}"

  // 서명 (Optional, 보안 강화)
  signature?: string;        // HMAC-SHA256
}

// 예시
const qrPayload: QRCodePayload = {
  version: "1.0",
  productId: "550e8400-e29b-41d4-a716-446655440000",
  sellerId: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  timestamp: "2025-10-30T12:00:00Z",
  url: "https://everseconds.com/product/550e8400-e29b-41d4-a716-446655440000",
  signature: "a3d5e8f2b1c4..."
};
```

### 3.2 QR 코드 인코딩

```typescript
import QRCode from 'qrcode';
import crypto from 'crypto';

// QR 코드 생성 함수
async function generateQRCode(productId: string, sellerId: string): Promise<string> {
  // 페이로드 구성
  const payload: QRCodePayload = {
    version: "1.0",
    productId,
    sellerId,
    timestamp: new Date().toISOString(),
    url: `https://everseconds.com/product/${productId}`,
  };

  // 서명 생성 (선택적)
  const secretKey = process.env.QR_SECRET_KEY!;
  const dataToSign = `${payload.productId}:${payload.sellerId}:${payload.timestamp}`;
  payload.signature = crypto
    .createHmac('sha256', secretKey)
    .update(dataToSign)
    .digest('hex');

  // JSON 문자열로 변환
  const qrData = JSON.stringify(payload);

  // QR 코드 이미지 생성 (Base64 Data URL)
  const qrCodeDataUrl = await QRCode.toDataURL(qrData, {
    errorCorrectionLevel: 'H',  // High error correction (30%)
    type: 'image/png',
    width: 512,
    margin: 2,
    color: {
      dark: '#000000',
      light: '#FFFFFF',
    },
  });

  return qrCodeDataUrl;
}
```

---

## 📸 QR 코드 생성

### 4.1 생성 시점

```typescript
// 상품 등록 완료 시 자동 생성
async function createProduct(productData: ProductInput): Promise<Product> {
  // 1. 상품 정보 저장
  const { data: product, error } = await supabase
    .from('products')
    .insert(productData)
    .select()
    .single();

  if (error) throw error;

  // 2. QR 코드 생성
  const qrCodeDataUrl = await generateQRCode(product.id, product.seller_id);

  // 3. QR 코드 이미지 Supabase Storage에 업로드
  const fileName = `qr_${product.id}.png`;
  const base64Data = qrCodeDataUrl.replace(/^data:image\/\w+;base64,/, '');
  const buffer = Buffer.from(base64Data, 'base64');

  const { error: uploadError } = await supabase.storage
    .from('qr-codes')
    .upload(fileName, buffer, {
      contentType: 'image/png',
      cacheControl: '31536000', // 1년
      upsert: false,
    });

  if (uploadError) throw uploadError;

  // 4. Public URL 생성
  const { data: urlData } = supabase.storage
    .from('qr-codes')
    .getPublicUrl(fileName);

  // 5. 상품에 QR 코드 URL 저장
  await supabase
    .from('products')
    .update({ qr_code_url: urlData.publicUrl })
    .eq('id', product.id);

  return {
    ...product,
    qr_code_url: urlData.publicUrl,
  };
}
```

### 4.2 QR 코드 디자인

```
┌─────────────────────────┐
│  에버세컨즈 🎯           │
├─────────────────────────┤
│                         │
│   ┌─────────────────┐   │
│   │                 │   │
│   │                 │   │
│   │   QR CODE       │   │
│   │                 │   │
│   │                 │   │
│   └─────────────────┘   │
│                         │
│   아이폰 13 Pro          │
│   800,000원             │
│                         │
│   판매자: 홍길동          │
│   등록일: 2025.10.30     │
│                         │
│   ID: PRD-A1B2C3         │
├─────────────────────────┤
│  스캔하여 상품 정보 확인 │
│  everseconds.com        │
└─────────────────────────┘
```

**디자인 사양**:
```typescript
interface QRCodeDesign {
  // 전체 크기
  width: 400;   // px
  height: 600;  // px

  // QR 코드
  qrSize: 300;  // px
  qrMargin: 50; // px

  // 텍스트
  title: {
    fontSize: 24;
    fontWeight: 'bold';
    color: '#111827';
  };
  subtitle: {
    fontSize: 16;
    fontWeight: 'normal';
    color: '#6b7280';
  };

  // 색상
  backgroundColor: '#ffffff';
  borderColor: '#e5e7eb';
  borderWidth: 2;
}
```

---

## 📱 QR 코드 스캔

### 5.1 스캔 방법

**옵션 1: 웹 기반 스캔 (추천)**
```typescript
// HTML5 QR Code 라이브러리 사용
import { Html5Qrcode } from 'html5-qrcode';

const QRScanner: React.FC = () => {
  const [scanning, setScanning] = useState(false);
  const [result, setResult] = useState<QRCodePayload | null>(null);

  const startScanning = async () => {
    const html5QrCode = new Html5Qrcode('qr-reader');

    try {
      await html5QrCode.start(
        { facingMode: 'environment' }, // 후면 카메라
        {
          fps: 10,
          qrbox: { width: 250, height: 250 },
          aspectRatio: 1.0,
        },
        (decodedText) => {
          // 성공
          const payload = JSON.parse(decodedText) as QRCodePayload;
          setResult(payload);

          // 상품 페이지로 리다이렉트
          window.location.href = payload.url;

          // 스캔 중지
          html5QrCode.stop();
        },
        (errorMessage) => {
          // 실패 (무시, 계속 스캔)
        }
      );

      setScanning(true);
    } catch (error) {
      console.error('QR 스캔 시작 실패:', error);
      alert('카메라 권한을 허용해주세요.');
    }
  };

  return (
    <div className="qr-scanner">
      <div id="qr-reader" style={{ width: '100%' }}></div>
      {!scanning && (
        <button onClick={startScanning}>스캔 시작</button>
      )}
    </div>
  );
};
```

**옵션 2: 네이티브 카메라 (Flutter)**
```dart
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.blue,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 250,
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      // QR 데이터 파싱
      final payload = jsonDecode(scanData.code!);
      final productId = payload['productId'];

      // 상품 페이지로 이동
      Navigator.pushNamed(
        context,
        '/product',
        arguments: {'id': productId},
      );

      // 스캔 중지
      await controller.pauseCamera();
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
```

### 5.2 QR 코드 검증

```typescript
// 서버 측 검증
async function validateQRCode(payload: QRCodePayload): Promise<boolean> {
  // 1. 버전 확인
  if (payload.version !== '1.0') {
    console.error('Unsupported QR version:', payload.version);
    return false;
  }

  // 2. 상품 존재 확인
  const { data: product, error } = await supabase
    .from('products')
    .select('id, seller_id, status')
    .eq('id', payload.productId)
    .single();

  if (error || !product) {
    console.error('Product not found:', payload.productId);
    return false;
  }

  // 3. 판매자 ID 일치 확인
  if (product.seller_id !== payload.sellerId) {
    console.error('Seller ID mismatch');
    return false;
  }

  // 4. 상품 상태 확인
  if (product.status === 'deleted' || product.status === 'sold') {
    console.warn('Product is no longer available');
    return false;
  }

  // 5. 서명 검증 (Optional)
  if (payload.signature) {
    const secretKey = process.env.QR_SECRET_KEY!;
    const dataToVerify = `${payload.productId}:${payload.sellerId}:${payload.timestamp}`;
    const expectedSignature = crypto
      .createHmac('sha256', secretKey)
      .update(dataToVerify)
      .digest('hex');

    if (payload.signature !== expectedSignature) {
      console.error('Invalid signature');
      return false;
    }
  }

  // 모든 검증 통과
  return true;
}
```

---

## 📊 스캔 추적

### 6.1 스캔 이벤트 로깅

```typescript
interface QRScanLog {
  id: string;
  productId: string;
  scannedBy?: string;       // 로그인 사용자인 경우
  ipAddress: string;
  userAgent: string;
  location?: {
    latitude: number;
    longitude: number;
  };
  scannedAt: Date;
}

// 스캔 로그 저장
async function logQRScan(payload: QRCodePayload, request: Request) {
  const scanLog: Omit<QRScanLog, 'id'> = {
    productId: payload.productId,
    scannedBy: getCurrentUser()?.id,
    ipAddress: request.headers.get('x-forwarded-for') || request.headers.get('x-real-ip') || 'unknown',
    userAgent: request.headers.get('user-agent') || 'unknown',
    scannedAt: new Date(),
  };

  // 위치 정보 (선택적, 사용자 동의 필요)
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition((position) => {
      scanLog.location = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      };
    });
  }

  // 데이터베이스에 저장
  await supabase.from('qr_scan_logs').insert(scanLog);

  // 상품 조회수 증가
  await supabase.rpc('increment_views', { product_id: payload.productId });
}
```

### 6.2 스캔 통계

```sql
-- QR 스캔 로그 테이블
CREATE TABLE qr_scan_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  scanned_by UUID REFERENCES users(id),
  ip_address INET,
  user_agent TEXT,
  location POINT,  -- PostgreSQL 지리 데이터 타입
  scanned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스
CREATE INDEX idx_qr_scan_logs_product_id ON qr_scan_logs(product_id);
CREATE INDEX idx_qr_scan_logs_scanned_at ON qr_scan_logs(scanned_at DESC);
CREATE INDEX idx_qr_scan_logs_location ON qr_scan_logs USING GIST(location);

-- 상품별 스캔 통계
CREATE OR REPLACE FUNCTION get_qr_scan_stats(product_id UUID)
RETURNS TABLE(
  total_scans BIGINT,
  unique_users BIGINT,
  today_scans BIGINT,
  this_week_scans BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) AS total_scans,
    COUNT(DISTINCT scanned_by) FILTER (WHERE scanned_by IS NOT NULL) AS unique_users,
    COUNT(*) FILTER (WHERE scanned_at::DATE = CURRENT_DATE) AS today_scans,
    COUNT(*) FILTER (WHERE scanned_at >= CURRENT_DATE - INTERVAL '7 days') AS this_week_scans
  FROM qr_scan_logs
  WHERE qr_scan_logs.product_id = get_qr_scan_stats.product_id;
END;
$$ LANGUAGE plpgsql;
```

---

## 🖨️ QR 코드 출력

### 7.1 키오스크 프린터 출력

```typescript
// Thermal Printer (열전사 프린터) 지원
async function printQRCode(product: Product) {
  const printContent = `
    ━━━━━━━━━━━━━━━━━━━━━━
    에버세컨즈 🎯
    ━━━━━━━━━━━━━━━━━━━━━━

    [QR CODE IMAGE]

    ${product.title}
    ${product.price.toLocaleString()}원

    판매자: ${product.seller.name}
    등록일: ${formatDate(product.created_at)}

    ID: ${product.id.slice(0, 8).toUpperCase()}
    ━━━━━━━━━━━━━━━━━━━━━━
    스캔하여 상품 정보 확인
    everseconds.com
    ━━━━━━━━━━━━━━━━━━━━━━
  `;

  // ESC/POS 명령어로 변환
  const escpos = require('escpos');
  escpos.USB = require('escpos-usb');

  const device = new escpos.USB();
  const printer = new escpos.Printer(device);

  device.open(async () => {
    // QR 코드 이미지 로드
    const qrImage = await escpos.Image.load(product.qr_code_url);

    printer
      .align('CT')  // Center
      .text('에버세컨즈 🎯')
      .feed(1)
      .image(qrImage, 'd24')  // Double density
      .feed(1)
      .text(product.title)
      .text(`${product.price.toLocaleString()}원`)
      .feed(1)
      .text(`판매자: ${product.seller.name}`)
      .text(`등록일: ${formatDate(product.created_at)}`)
      .feed(1)
      .text(`ID: ${product.id.slice(0, 8).toUpperCase()}`)
      .feed(1)
      .text('스캔하여 상품 정보 확인')
      .text('everseconds.com')
      .feed(2)
      .cut()  // 용지 절단
      .close();
  });
}
```

### 7.2 모바일로 전송

```typescript
// 카카오톡으로 QR 이미지 전송
async function sendQRToPhone(product: Product, userId: string) {
  const { data: user } = await supabase
    .from('users')
    .select('kakao_id')
    .eq('id', userId)
    .single();

  if (!user?.kakao_id) {
    throw new Error('Kakao ID not found');
  }

  // Kakao Message API 사용
  const Kakao = window.Kakao;

  Kakao.Link.sendDefault({
    objectType: 'feed',
    content: {
      title: product.title,
      description: `${product.price.toLocaleString()}원`,
      imageUrl: product.qr_code_url,
      link: {
        mobileWebUrl: `https://everseconds.com/product/${product.id}`,
        webUrl: `https://everseconds.com/product/${product.id}`,
      },
    },
    buttons: [
      {
        title: '상품 보기',
        link: {
          mobileWebUrl: `https://everseconds.com/product/${product.id}`,
          webUrl: `https://everseconds.com/product/${product.id}`,
        },
      },
    ],
  });
}

// 또는 이메일로 전송
async function sendQRByEmail(product: Product, email: string) {
  // SendGrid, AWS SES 등 이메일 서비스 사용
  const emailContent = {
    to: email,
    from: 'noreply@everseconds.com',
    subject: `[에버세컨즈] ${product.title} QR 코드`,
    html: `
      <h2>상품 등록이 완료되었습니다!</h2>
      <p><strong>${product.title}</strong></p>
      <p>가격: ${product.price.toLocaleString()}원</p>
      <img src="${product.qr_code_url}" alt="QR Code" style="width: 300px;" />
      <p>이 QR 코드를 상품에 부착해주세요.</p>
      <a href="${product.url}">상품 보기</a>
    `,
  };

  await sendEmail(emailContent);
}
```

---

## 🔒 보안

### 8.1 QR 코드 위조 방지

```typescript
// 1. HMAC 서명
function generateSignature(data: string, secret: string): string {
  return crypto.createHmac('sha256', secret).update(data).digest('hex');
}

// 2. 타임스탬프 검증 (재사용 방지)
function validateTimestamp(timestamp: string, maxAgeMinutes: number = 60): boolean {
  const qrTime = new Date(timestamp);
  const now = new Date();
  const ageMinutes = (now.getTime() - qrTime.getTime()) / 1000 / 60;

  return ageMinutes <= maxAgeMinutes;
}

// 3. Rate Limiting (동일 QR 반복 스캔 방지)
const scanRateLimit = new Map<string, number>();

function checkScanRateLimit(productId: string, maxScansPerMinute: number = 10): boolean {
  const key = `${productId}:${Date.now()}`;
  const count = scanRateLimit.get(key) || 0;

  if (count >= maxScansPerMinute) {
    return false; // Rate limit exceeded
  }

  scanRateLimit.set(key, count + 1);
  return true;
}
```

### 8.2 가짜 QR 탐지

```typescript
// 의심스러운 스캔 패턴 탐지
async function detectSuspiciousQRScans() {
  // 1. 짧은 시간에 너무 많은 스캔
  const suspiciousHighFrequency = await supabase
    .from('qr_scan_logs')
    .select('product_id, COUNT(*)')
    .gte('scanned_at', new Date(Date.now() - 60000)) // 1분 이내
    .group('product_id')
    .having('COUNT(*) > 50');

  // 2. 동일 IP에서 여러 상품 스캔
  const suspiciousIP = await supabase
    .from('qr_scan_logs')
    .select('ip_address, COUNT(DISTINCT product_id)')
    .gte('scanned_at', new Date(Date.now() - 300000)) // 5분 이내
    .group('ip_address')
    .having('COUNT(DISTINCT product_id) > 20');

  // 3. 알림 발송
  if (suspiciousHighFrequency.data?.length || suspiciousIP.data?.length) {
    await notifyAdmins('Suspicious QR scan activity detected');
  }
}
```

---

## 📈 성능 최적화

### 9.1 QR 코드 캐싱

```typescript
// CDN 캐싱 (Vercel Edge, Cloudflare)
export const config = {
  runtime: 'edge',
};

export default async function handler(req: Request) {
  const { productId } = await req.json();

  // QR 코드 URL 조회 (캐시된 응답)
  const { data } = await supabase
    .from('products')
    .select('qr_code_url')
    .eq('id', productId)
    .single();

  return new Response(JSON.stringify({ qrCodeUrl: data.qr_code_url }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=31536000, immutable', // 1년
    },
  });
}
```

### 9.2 Lazy Loading

```typescript
// QR 코드 이미지 지연 로딩
function QRCodeImage({ src, alt }: { src: string; alt: string }) {
  return (
    <img
      src={src}
      alt={alt}
      loading="lazy"
      decoding="async"
      style={{ width: '100%', height: 'auto' }}
    />
  );
}
```

---

## 📱 모바일 앱 통합

### 10.1 Deep Linking

```typescript
// Universal Links (iOS) / App Links (Android)
const deepLinkConfig = {
  scheme: 'everseconds',
  host: 'product',
};

// QR 스캔 후 앱으로 리다이렉트
function handleQRScan(payload: QRCodePayload) {
  const deepLink = `everseconds://product/${payload.productId}`;
  const webLink = payload.url;

  // 앱이 설치되어 있으면 앱 열기, 아니면 웹
  if (isAppInstalled()) {
    window.location.href = deepLink;
  } else {
    window.location.href = webLink;
  }
}
```

---

## 🧪 테스트

### 11.1 QR 코드 생성 테스트

```typescript
describe('QR Code Generation', () => {
  it('should generate valid QR code', async () => {
    const product = await createProduct({
      title: 'Test Product',
      price: 10000,
      // ... other fields
    });

    expect(product.qr_code_url).toBeDefined();
    expect(product.qr_code_url).toMatch(/^https:\/\//);
  });

  it('should include correct payload', async () => {
    const qrCodeDataUrl = await generateQRCode('product-id', 'seller-id');
    // Decode and verify
    const payload = JSON.parse(decodeQRCode(qrCodeDataUrl));

    expect(payload.productId).toBe('product-id');
    expect(payload.sellerId).toBe('seller-id');
    expect(payload.version).toBe('1.0');
  });
});
```

### 11.2 스캔 검증 테스트

```typescript
describe('QR Code Validation', () => {
  it('should validate correct QR code', async () => {
    const validPayload: QRCodePayload = {
      version: '1.0',
      productId: 'valid-id',
      sellerId: 'valid-seller-id',
      timestamp: new Date().toISOString(),
      url: 'https://everseconds.com/product/valid-id',
    };

    const isValid = await validateQRCode(validPayload);
    expect(isValid).toBe(true);
  });

  it('should reject invalid signature', async () => {
    const invalidPayload: QRCodePayload = {
      version: '1.0',
      productId: 'valid-id',
      sellerId: 'valid-seller-id',
      timestamp: new Date().toISOString(),
      url: 'https://everseconds.com/product/valid-id',
      signature: 'invalid-signature',
    };

    const isValid = await validateQRCode(invalidPayload);
    expect(isValid).toBe(false);
  });
});
```

---

## 📚 참고 자료

### 12.1 QR 코드 표준
- ISO/IEC 18004:2015 (QR Code specification)
- Error Correction Levels: L (7%), M (15%), Q (25%), H (30%)

### 12.2 라이브러리
- **생성**: qrcode (Node.js), qr_flutter (Flutter)
- **스캔**: html5-qrcode (Web), qr_code_scanner (Flutter)

---

**문서 버전**: 1.0
**최종 수정일**: 2025-10-30
**작성자**: 에버세컨즈 개발팀
**관련 문서**: [프로젝트 개요](./프로젝트_개요.md)
