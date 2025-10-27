'use client';

import React, { useState, useCallback } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import QRCodeModal from '@/components/QRCodeModal';
import Toast from '@/components/Toast';
import { useToast } from '@/hooks/useToast';
import { Shop, ShopProduct } from '@/types';
import { getProductImageUrl } from '@/lib/utils/imageUtils';
import { formatKRW } from '@/lib/utils/currency';

interface ShopPageClientProps {
  shop: Shop;
  ownProducts: ShopProduct[];
  resaleProducts: ShopProduct[];
  shareUrl: string;
}

export default function ShopPageClient({
  shop,
  ownProducts,
  resaleProducts,
  shareUrl,
}: ShopPageClientProps) {
  const [activeTab, setActiveTab] = useState<'own' | 'resale'>('own');
  const [showQRModal, setShowQRModal] = useState(false);
  const { toasts, hideToast, success } = useToast();

  // Memoized share handler
  const handleShare = useCallback(() => {
    const webLink = `${window.location.origin}/shop/${shareUrl}`;
    navigator.clipboard.writeText(webLink);
    success('샵 링크가 복사되었습니다!');
  }, [shareUrl, success]);

  return (
    <>
      <div className="min-h-screen bg-gray-50">
        {/* Header */}
        <header className="bg-white shadow-sm sticky top-0 z-40">
          <div className="container mx-auto px-4 py-4">
            <div className="flex items-center justify-between">
              <Link href="/" className="flex items-center gap-2">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M10 19l-7-7m0 0l7-7m-7 7h18"
                  />
                </svg>
                <span className="font-bold text-xl text-blue-600">에버세컨즈</span>
              </Link>

              <div className="flex items-center gap-3">
                <button
                  onClick={handleShare}
                  className="flex items-center gap-2 px-3 py-2 text-gray-600 hover:text-gray-900 transition-colors"
                  aria-label="샵 링크 공유"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"
                    />
                  </svg>
                  공유
                </button>

                <button
                  onClick={() => setShowQRModal(true)}
                  className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
                  aria-label="앱 설치 QR 코드 보기"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"
                    />
                  </svg>
                  앱 설치
                </button>
              </div>
            </div>
          </div>
        </header>

        {/* Shop Header */}
        <div className="bg-gradient-to-br from-blue-50 to-blue-100 py-8">
          <div className="container mx-auto px-4">
            <div className="flex items-center gap-6">
              <div className="w-20 h-20 bg-white rounded-full flex items-center justify-center shadow-md">
                <svg className="w-10 h-10 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z" />
                </svg>
              </div>
              <div className="flex-1">
                <h1 className="text-3xl font-bold text-gray-900 mb-2">{shop.name}</h1>
                <p className="text-gray-600">{shop.description || '안녕하세요!'}</p>
                <div className="mt-3 text-sm text-gray-500">
                  {ownProducts.length + resaleProducts.length}개의 상품을 판매중이에요
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="bg-white border-b sticky top-16 z-30">
          <div className="container mx-auto px-4">
            <div className="flex gap-8">
              <button
                onClick={() => setActiveTab('own')}
                className={`py-4 px-2 font-semibold border-b-2 transition-colors ${
                  activeTab === 'own'
                    ? 'border-blue-600 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700'
                }`}
              >
                판매 상품
                <span className="ml-2 bg-blue-100 text-blue-600 px-2 py-1 rounded-full text-xs">
                  {ownProducts.length}
                </span>
              </button>
              <button
                onClick={() => setActiveTab('resale')}
                className={`py-4 px-2 font-semibold border-b-2 transition-colors ${
                  activeTab === 'resale'
                    ? 'border-green-600 text-green-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700'
                }`}
              >
                대신팔기 상품
                <span className="ml-2 bg-green-100 text-green-600 px-2 py-1 rounded-full text-xs">
                  {resaleProducts.length}
                </span>
              </button>
            </div>
          </div>
        </div>

        {/* Product Grid */}
        <main className="container mx-auto px-4 py-8">
          {activeTab === 'own' ? (
            ownProducts.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
                {ownProducts.map((product) => (
                  <Link key={product.id} href={`/product/${product.id}`}>
                    <div className="bg-white rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow">
                      <div className="relative aspect-square bg-gray-100">
                        <Image
                          src={getProductImageUrl(product.images, 0)}
                          alt={product.title}
                          fill
                          className="object-cover"
                          loading="lazy"
                          sizes="(max-width: 768px) 50vw, (max-width: 1024px) 33vw, 20vw"
                        />
                        {product.resale_enabled && (
                          <div className="absolute top-2 right-2 bg-orange-100 text-orange-700 px-2 py-1 rounded-md text-xs font-semibold">
                            대신팔기
                          </div>
                        )}
                      </div>
                      <div className="p-3">
                        <h3 className="font-medium text-sm mb-1 line-clamp-2">{product.title}</h3>
                        <p className="font-bold text-lg">{formatKRW(product.price)}</p>
                      </div>
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="text-center py-16">
                <svg
                  className="mx-auto h-12 w-12 text-gray-400 mb-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
                  />
                </svg>
                <p className="text-gray-500 text-lg">판매중인 상품이 없습니다</p>
              </div>
            )
          ) : resaleProducts.length > 0 ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
              {resaleProducts.map((product) => (
                <Link key={product.id} href={`/product/${product.id}`}>
                  <div className="bg-white rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow">
                    <div className="relative aspect-square bg-gray-100">
                      <Image
                        src={getProductImageUrl(product.images, 0)}
                        alt={product.title}
                        fill
                        className="object-cover"
                        loading="lazy"
                        sizes="(max-width: 768px) 50vw, (max-width: 1024px) 33vw, 20vw"
                      />
                      <div className="absolute top-2 right-2 bg-green-100 text-green-700 px-2 py-1 rounded-md text-xs font-semibold">
                        대신팔기
                      </div>
                    </div>
                    <div className="p-3">
                      <h3 className="font-medium text-sm mb-1 line-clamp-2">{product.title}</h3>
                      <p className="font-bold text-lg">{formatKRW(product.price)}</p>
                      {product.resale_fee_percentage && (
                        <p className="text-xs text-green-600 mt-1">
                          수수료 {product.resale_fee_percentage}%
                        </p>
                      )}
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <div className="text-center py-16">
              <svg
                className="mx-auto h-12 w-12 text-gray-400 mb-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
                />
              </svg>
              <p className="text-gray-500 text-lg">대신팔기 상품이 없습니다</p>
            </div>
          )}
        </main>
      </div>

      {/* QR Code Modal */}
      <QRCodeModal isOpen={showQRModal} onClose={() => setShowQRModal(false)} />

      {/* Toast Notifications */}
      {toasts.map((toast, index) => (
        <Toast
          key={toast.id}
          message={toast.message}
          type={toast.type}
          index={index}
          onClose={() => hideToast(toast.id)}
        />
      ))}
    </>
  );
}
