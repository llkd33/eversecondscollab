'use client';

import React from 'react';
import Image from 'next/image';
import { Product } from '@/types';

interface ProductInfoProps {
  product: Product;
  formatPrice: (price: number) => string;
  formatDate: (date: Date) => string;
  isKioskMode: boolean;
  onShowQRModal: () => void;
}

export default function ProductInfo({
  product,
  formatPrice,
  formatDate,
  isKioskMode,
  onShowQRModal,
}: ProductInfoProps) {
  return (
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

        {product.resaleEnabled && product.commissionRate !== undefined && product.commissionAmount !== undefined && (
          <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <svg className="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fillRule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z"
                    clipRule="evenodd"
                  />
                </svg>
                <span className="font-semibold text-green-700">대신팔기 수수료</span>
              </div>
              <div className="text-right">
                <div className="font-bold text-green-700">{product.commissionRate}%</div>
                <div className="text-sm text-green-600">{formatPrice(product.commissionAmount)}</div>
              </div>
            </div>
          </div>
        )}

        <div className="text-gray-600 text-sm">{formatDate(product.createdAt)} 등록</div>
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
                loading="lazy"
                sizes="64px"
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
              onClick={onShowQRModal}
              className="bg-orange-500 text-white font-semibold py-3 px-4 rounded-lg hover:bg-orange-600 transition-colors flex items-center justify-center gap-2"
            >
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
              </svg>
              대신팔기
            </button>
          )}

          <button
            onClick={onShowQRModal}
            className={`bg-blue-600 text-white font-semibold py-3 px-4 rounded-lg hover:bg-blue-700 transition-colors ${
              !product.resaleEnabled ? 'col-span-2' : ''
            }`}
          >
            구매하기
          </button>

          <button
            onClick={onShowQRModal}
            className="col-span-2 bg-gray-100 text-gray-700 font-semibold py-3 px-4 rounded-lg hover:bg-gray-200 transition-colors flex items-center justify-center gap-2"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
              />
            </svg>
            채팅하기
          </button>
        </div>

        <div className="mt-4 p-4 bg-blue-50 rounded-lg">
          <p className="text-sm text-blue-700 text-center">안전한 거래를 위해 앱을 다운로드하세요</p>
        </div>
      </div>
    </div>
  );
}
