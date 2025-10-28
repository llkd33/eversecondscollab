'use client';

import React, { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Image from 'next/image';
import { Product } from '@/types';
import { productService } from '@/lib/supabase/products';
import { transactionService } from '@/lib/supabase/transactions';
import { userService } from '@/lib/supabase/users';
import { colors } from '@/lib/theme';

export default function ProductDetailPage() {
  const params = useParams();
  const router = useRouter();
  const productId = params.id as string;

  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [purchasing, setPurchasing] = useState(false);

  useEffect(() => {
    const loadProductAndUser = async () => {
      try {
        setLoading(true);
        setError(null);

        // Load product
        const productData = await productService.getProductById(productId);
        setProduct(productData);

        // Load current user
        const userData = await userService.getCurrentUser();
        setCurrentUser(userData);
      } catch (err) {
        console.error('Error loading product:', err);
        setError('상품을 불러오는데 실패했습니다.');
      } finally {
        setLoading(false);
      }
    };

    if (productId) {
      loadProductAndUser();
    }
  }, [productId]);

  const handlePurchase = async () => {
    if (!product || !currentUser) {
      alert('로그인이 필요합니다.');
      return;
    }

    if (product.sellerId === currentUser.id) {
      alert('자신의 상품은 구매할 수 없습니다.');
      return;
    }

    try {
      setPurchasing(true);

      const transaction = await transactionService.createTransaction({
        productId: product.id,
        buyerId: currentUser.id,
        sellerId: product.sellerId,
        price: product.price,
        commissionRate: product.commissionRate,
      });

      alert('구매 요청이 완료되었습니다!');
      router.push(`/transactions/${transaction.id}`);
    } catch (err) {
      console.error('Error creating transaction:', err);
      alert('구매 요청 중 오류가 발생했습니다.');
    } finally {
      setPurchasing(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div
          className="animate-spin rounded-full h-12 w-12 border-b-2"
          style={{ borderColor: colors.primary }}
        ></div>
      </div>
    );
  }

  if (error || !product) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <svg
            className="mx-auto h-12 w-12 mb-4"
            style={{ color: colors.error }}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <p className="text-gray-700 text-lg mb-4">{error || '상품을 찾을 수 없습니다'}</p>
          <button
            onClick={() => router.push('/')}
            className="px-4 py-2 rounded-lg text-white font-medium"
            style={{ backgroundColor: colors.primary }}
          >
            홈으로 돌아가기
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center gap-4">
            <button
              onClick={() => router.back()}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <h1
              className="text-2xl font-bold"
              style={{ color: colors.primary }}
            >
              에버세컨즈
            </h1>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8 max-w-6xl">
        <div className="grid md:grid-cols-2 gap-8">
          {/* Image Gallery */}
          <div className="space-y-4">
            <div className="relative aspect-square bg-gray-200 rounded-lg overflow-hidden">
              {product.images && product.images.length > 0 ? (
                <Image
                  src={product.images[currentImageIndex]}
                  alt={product.title}
                  fill
                  className="object-cover"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <svg className="w-20 h-20 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
              )}
            </div>

            {/* Image Thumbnails */}
            {product.images && product.images.length > 1 && (
              <div className="flex gap-2 overflow-x-auto">
                {product.images.map((image, index) => (
                  <button
                    key={index}
                    onClick={() => setCurrentImageIndex(index)}
                    className={`relative w-20 h-20 flex-shrink-0 rounded-lg overflow-hidden ${
                      index === currentImageIndex ? 'ring-2' : ''
                    }`}
                    style={index === currentImageIndex ? { ringColor: colors.primary } : {}}
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
            )}
          </div>

          {/* Product Info */}
          <div className="space-y-6">
            <div>
              <span
                className="inline-block px-3 py-1 rounded-lg text-sm font-medium mb-3"
                style={{ backgroundColor: `${colors.secondary}20`, color: colors.secondary }}
              >
                {product.category.name}
              </span>
              <h1 className="text-3xl font-bold text-gray-900 mb-2">{product.title}</h1>
              <p className="text-4xl font-bold" style={{ color: colors.primary }}>
                {product.price.toLocaleString()}원
              </p>
            </div>

            {/* Seller Info */}
            <div className="p-4 bg-gray-100 rounded-lg">
              <h3 className="text-sm font-semibold text-gray-700 mb-2">판매자 정보</h3>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-gray-300 rounded-full flex items-center justify-center">
                  <svg className="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                </div>
                <div>
                  <p className="font-semibold">{product.sellerInfo.name}</p>
                  <div className="flex items-center gap-2 text-sm text-gray-600">
                    <span>레벨 {product.sellerInfo.level}</span>
                    <span>·</span>
                    <span>평점 {product.sellerInfo.rating}</span>
                    <span>·</span>
                    <span>거래 {product.sellerInfo.totalTransactions}회</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Description */}
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-3">상품 설명</h3>
              <p className="text-gray-700 whitespace-pre-wrap">{product.description}</p>
            </div>

            {/* Resale Info */}
            {product.resaleEnabled && (
              <div className="p-4 rounded-lg" style={{ backgroundColor: `${colors.accent}10` }}>
                <div className="flex items-start gap-3">
                  <svg className="w-6 h-6 flex-shrink-0" style={{ color: colors.accent }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  <div>
                    <h4 className="font-semibold mb-1" style={{ color: colors.accent }}>
                      재판매 가능 상품
                    </h4>
                    <p className="text-sm text-gray-600">
                      이 상품은 구매 후 재판매가 가능합니다.
                      재판매 시 {product.commissionRate}%의 수수료가 발생합니다.
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Action Buttons */}
            <div className="sticky bottom-0 bg-white p-4 border-t space-y-3">
              <button
                onClick={handlePurchase}
                disabled={purchasing || product.status !== 'active'}
                className="w-full py-4 rounded-lg text-white font-semibold text-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                style={{
                  backgroundColor: product.status === 'active' ? colors.primary : colors.textDisabled,
                }}
              >
                {purchasing ? '처리 중...' : product.status === 'active' ? '구매하기' : '판매 완료'}
              </button>

              {product.status === 'active' && (
                <button
                  className="w-full py-4 rounded-lg font-semibold text-lg transition-colors"
                  style={{
                    border: `2px solid ${colors.secondary}`,
                    color: colors.secondary,
                    backgroundColor: 'white',
                  }}
                  onClick={() => alert('채팅 기능은 준비 중입니다.')}
                >
                  채팅하기
                </button>
              )}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
