'use client';

import React from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { Product } from '@/types';

interface ProductCardProps {
  product: Product;
  isKioskMode?: boolean;
}

export default function ProductCard({ product, isKioskMode = false }: ProductCardProps) {
  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW',
    }).format(price);
  };

  const cardSize = isKioskMode ? 'min-h-[320px]' : 'min-h-[280px]';
  const imageSize = isKioskMode ? 'h-48' : 'h-40';
  const textSize = isKioskMode ? 'text-lg' : 'text-base';

  return (
    <Link href={`/product/${product.id}`}>
      <div className={`bg-white rounded-xl overflow-hidden shadow-sm hover:shadow-lg transition-all duration-300 cursor-pointer ${cardSize} flex flex-col`}>
        {/* Image Container */}
        <div className={`relative ${imageSize} bg-gray-100`}>
          {product.images[0] ? (
            <Image
              src={product.images[0]}
              alt={product.title}
              fill
              className="object-cover"
              sizes="(max-width: 768px) 50vw, (max-width: 1024px) 33vw, 25vw"
            />
          ) : (
            <div className="flex items-center justify-center h-full">
              <svg
                className="w-12 h-12 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
            </div>
          )}
          
          {/* Status Badge */}
          {product.status === 'sold' && (
            <div className="absolute top-2 left-2 bg-gray-900 bg-opacity-75 text-white px-3 py-1 rounded-lg text-sm font-semibold">
              판매완료
            </div>
          )}
          
          {/* Resale Badge */}
          {product.resaleEnabled && (
            <div className="absolute top-2 right-2 bg-orange-500 text-white px-3 py-1 rounded-lg text-sm font-semibold flex items-center gap-1">
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
              </svg>
              대신팔기
            </div>
          )}
        </div>

        {/* Content */}
        <div className="p-4 flex-1 flex flex-col">
          <h3 className={`font-semibold text-gray-900 mb-2 line-clamp-2 ${textSize}`}>
            {product.title}
          </h3>
          
          <div className="flex-1" />
          
          <div className="space-y-2">
            {/* Price */}
            <p className={`font-bold text-gray-900 ${isKioskMode ? 'text-xl' : 'text-lg'}`}>
              {formatPrice(product.price)}
            </p>
            
            {/* Commission Info */}
            {product.resaleEnabled && product.commissionRate && (
              <div className="flex items-center gap-1 text-sm text-green-600">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clipRule="evenodd" />
                </svg>
                <span>수수료 {product.commissionRate}%</span>
              </div>
            )}
            
            {/* Seller Info */}
            <div className="flex items-center justify-between text-sm">
              <div className="flex items-center gap-2">
                <div className="w-6 h-6 bg-gray-200 rounded-full flex items-center justify-center">
                  <svg className="w-4 h-4 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
                  </svg>
                </div>
                <span className="text-gray-600">{product.sellerInfo.name}</span>
              </div>
              
              {/* Level Badge */}
              {product.sellerInfo.level >= 3 && (
                <span className="bg-blue-100 text-blue-700 px-2 py-1 rounded-md text-xs font-semibold">
                  Lv.{product.sellerInfo.level}
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
    </Link>
  );
}