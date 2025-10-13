'use client';

import React, { useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import QRCodeModal from '@/components/QRCodeModal';
import { Product, ProductStatus } from '@/types';

// Mock product data - In production, this would be fetched from Supabase
const mockProduct: Product = {
  id: '1',
  title: '나이키 운동화 270 리액트',
  price: 85000,
  description: `거의 새 제품입니다. 3번 정도만 착용했어요.
  
  - 사이즈: 270mm
  - 색상: 블랙/화이트
  - 구매시기: 2024년 1월
  - 박스, 여분끈 모두 포함
  
  직거래는 강남역에서 가능합니다.
  택배거래도 가능해요!`,
  images: [
    '/api/placeholder/800/800',
    '/api/placeholder/800/800',
    '/api/placeholder/800/800',
    '/api/placeholder/800/800',
  ],
  category: { id: '4', name: '스포츠', slug: 'sports' },
  sellerId: 'user1',
  sellerInfo: {
    id: 'user1',
    name: '김철수',
    level: 5,
    rating: 4.8,
    totalTransactions: 42,
    successRate: 98,
    profileImage: '/api/placeholder/100/100',
  },
  resaleEnabled: true,
  commissionRate: 15,
  commissionAmount: 12750,
  status: ProductStatus.ACTIVE,
  createdAt: new Date('2024-03-01'),
  updatedAt: new Date('2024-03-01'),
};

// Related products
const relatedProducts: Product[] = [
  {
    id: '2',
    title: '아디다스 울트라부스트',
    price: 95000,
    description: '상태 좋습니다',
    images: ['/api/placeholder/400/400'],
    category: { id: '4', name: '스포츠', slug: 'sports' },
    sellerId: 'user2',
    sellerInfo: {
      id: 'user2',
      name: '이영희',
      level: 3,
      rating: 4.5,
      totalTransactions: 15,
      successRate: 95,
    },
    resaleEnabled: false,
    status: ProductStatus.ACTIVE,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  // Add more related products
];

export default function ProductDetailPage() {
  const params = useParams();
  const [selectedImage, setSelectedImage] = useState(0);
  const [showQRModal, setShowQRModal] = useState(false);
  const [isKioskMode, setIsKioskMode] = useState(false);
  
  // In production, fetch product by params.id
  const product = mockProduct;

  React.useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    setIsKioskMode(urlParams.get('kiosk') === 'true');
  }, []);

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW',
    }).format(price);
  };

  const formatDate = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(hours / 24);
    
    if (hours < 1) return '방금 전';
    if (hours < 24) return `${hours}시간 전`;
    if (days < 7) return `${days}일 전`;
    return date.toLocaleDateString('ko-KR');
  };

  return (
    <>
      <div className="min-h-screen bg-gray-50">
        {/* Header */}
        <header className="bg-white shadow-sm sticky top-0 z-40">
          <div className="container mx-auto px-4 py-4">
            <div className="flex items-center justify-between">
              <Link href="/" className="flex items-center gap-2">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
                    d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
                <span className="font-bold text-xl text-blue-600">에버세컨즈</span>
              </Link>
              
              <button
                onClick={() => setShowQRModal(true)}
                className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
                    d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                </svg>
                앱 설치
              </button>
            </div>
          </div>
        </header>

        <main className="container mx-auto px-4 py-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-12">
            {/* Image Gallery */}
            <div className="bg-white rounded-xl overflow-hidden">
              {/* Main Image */}
              <div className="relative aspect-square bg-gray-100">
                {product.images[selectedImage] ? (
                  <Image
                    src={product.images[selectedImage]}
                    alt={product.title}
                    fill
                    className="object-cover"
                  />
                ) : (
                  <div className="flex items-center justify-center h-full">
                    <svg className="w-20 h-20 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
                        d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                )}
                
                {/* Status Badge */}
                {product.status === 'sold' && (
                  <div className="absolute top-4 left-4 bg-gray-900 bg-opacity-75 text-white px-4 py-2 rounded-lg text-lg font-semibold">
                    판매완료
                  </div>
                )}
              </div>
              
              {/* Thumbnail Images */}
              <div className="p-4">
                <div className="grid grid-cols-4 gap-2">
                  {product.images.map((image, index) => (
                    <button
                      key={index}
                      onClick={() => setSelectedImage(index)}
                      className={`relative aspect-square rounded-lg overflow-hidden border-2 transition-all ${
                        selectedImage === index ? 'border-blue-500' : 'border-gray-200'
                      }`}
                    >
                      <Image
                        src={image}
                        alt={`${product.title} ${index + 1}`}
                        fill
                        className="object-cover"
                      />
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Product Info */}
            <div className="space-y-6">
              {/* Basic Info */}
              <div className="bg-white rounded-xl p-6">
                <div className="flex items-center gap-2 mb-2">
                  <span className="bg-blue-100 text-blue-700 px-3 py-1 rounded-lg text-sm font-semibold">
                    {product.category.name}
                  </span>
                  {product.resaleEnabled && (
                    <span className="bg-orange-100 text-orange-700 px-3 py-1 rounded-lg text-sm font-semibold flex items-center gap-1">
                      <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
                      </svg>
                      대신팔기 가능
                    </span>
                  )}
                </div>
                
                <h1 className={`font-bold text-gray-900 mb-4 ${isKioskMode ? 'text-3xl' : 'text-2xl'}`}>
                  {product.title}
                </h1>
                
                <div className={`font-bold text-gray-900 mb-4 ${isKioskMode ? 'text-4xl' : 'text-3xl'}`}>
                  {formatPrice(product.price)}
                </div>
                
                {product.resaleEnabled && (
                  <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <svg className="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clipRule="evenodd" />
                        </svg>
                        <span className="font-semibold text-green-700">대신팔기 수수료</span>
                      </div>
                      <div className="text-right">
                        <div className="font-bold text-green-700">{product.commissionRate}%</div>
                        <div className="text-sm text-green-600">{formatPrice(product.commissionAmount!)}</div>
                      </div>
                    </div>
                  </div>
                )}
                
                <div className="text-gray-600 text-sm">
                  {formatDate(product.createdAt)} 등록
                </div>
              </div>

              {/* Seller Info */}
              <div className="bg-white rounded-xl p-6">
                <h2 className="font-semibold text-lg mb-4">판매자 정보</h2>
                <div className="flex items-center gap-4">
                  <div className="relative w-16 h-16 bg-gray-200 rounded-full overflow-hidden">
                    {product.sellerInfo.profileImage ? (
                      <Image
                        src={product.sellerInfo.profileImage}
                        alt={product.sellerInfo.name}
                        fill
                        className="object-cover"
                      />
                    ) : (
                      <div className="flex items-center justify-center h-full">
                        <svg className="w-10 h-10 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
                        </svg>
                      </div>
                    )}
                  </div>
                  
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-semibold text-lg">{product.sellerInfo.name}</h3>
                      <span className="bg-blue-100 text-blue-700 px-2 py-1 rounded-md text-xs font-semibold">
                        Lv.{product.sellerInfo.level}
                      </span>
                    </div>
                    
                    <div className="flex items-center gap-4 text-sm text-gray-600">
                      <div className="flex items-center gap-1">
                        <svg className="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                        </svg>
                        <span className="font-semibold">{product.sellerInfo.rating}</span>
                      </div>
                      <span>거래 {product.sellerInfo.totalTransactions}회</span>
                      <span>성공률 {product.sellerInfo.successRate}%</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="bg-white rounded-xl p-6">
                <div className="grid grid-cols-2 gap-3">
                  {product.resaleEnabled && (
                    <button
                      onClick={() => setShowQRModal(true)}
                      className="bg-orange-500 text-white font-semibold py-3 px-4 rounded-lg hover:bg-orange-600 transition-colors flex items-center justify-center gap-2"
                    >
                      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
                      </svg>
                      대신팔기
                    </button>
                  )}
                  
                  <button
                    onClick={() => setShowQRModal(true)}
                    className={`bg-blue-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-blue-700 transition-colors ${
                      !product.resaleEnabled ? 'col-span-2' : ''
                    }`}
                  >
                    구매하기
                  </button>
                  
                  <button
                    onClick={() => setShowQRModal(true)}
                    className="col-span-2 bg-gray-100 text-gray-700 font-semibold py-3 px-4 rounded-lg hover:bg-gray-200 transition-colors flex items-center justify-center gap-2"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
                        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                    채팅하기
                  </button>
                </div>
                
                <div className="mt-4 p-4 bg-blue-50 rounded-lg">
                  <p className="text-sm text-blue-700 text-center">
                    안전한 거래를 위해 앱을 다운로드하세요
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Description */}
          <div className="bg-white rounded-xl p-6 mb-8">
            <h2 className="font-semibold text-lg mb-4">상품 설명</h2>
            <div className="text-gray-700 whitespace-pre-line">
              {product.description}
            </div>
          </div>

          {/* Related Products */}
          <div className="mb-8">
            <h2 className="font-semibold text-xl mb-4">관련 상품</h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {relatedProducts.map((relatedProduct) => (
                <Link key={relatedProduct.id} href={`/product/${relatedProduct.id}`}>
                  <div className="bg-white rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow">
                    <div className="relative aspect-square bg-gray-100">
                      <Image
                        src={relatedProduct.images[0] || '/api/placeholder/400/400'}
                        alt={relatedProduct.title}
                        fill
                        className="object-cover"
                      />
                    </div>
                    <div className="p-3">
                      <h3 className="font-medium text-sm mb-1 line-clamp-2">{relatedProduct.title}</h3>
                      <p className="font-bold">{formatPrice(relatedProduct.price)}</p>
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          </div>
        </main>
      </div>

      {/* QR Code Modal */}
      <QRCodeModal 
        isOpen={showQRModal}
        onClose={() => setShowQRModal(false)}
        productId={product.id}
      />
    </>
  );
}