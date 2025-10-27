import React from 'react';

interface SkeletonProps {
  className?: string;
  variant?: 'text' | 'circular' | 'rectangular';
  width?: string | number;
  height?: string | number;
  animation?: 'pulse' | 'wave';
}

export function Skeleton({
  className = '',
  variant = 'rectangular',
  width,
  height,
  animation = 'pulse'
}: SkeletonProps) {
  const baseClasses = 'bg-gray-200';
  const animationClass = animation === 'pulse' ? 'animate-pulse' : 'animate-shimmer';

  const variantClasses = {
    text: 'rounded h-4',
    circular: 'rounded-full',
    rectangular: 'rounded-lg'
  };

  const style: React.CSSProperties = {
    width: width || '100%',
    height: height || (variant === 'text' ? '1rem' : variant === 'circular' ? '40px' : '200px')
  };

  return (
    <div
      className={`${baseClasses} ${variantClasses[variant]} ${animationClass} ${className}`}
      style={style}
      aria-label="로딩 중"
    />
  );
}

// Product Card Skeleton
export function ProductCardSkeleton({ isKioskMode = false }: { isKioskMode?: boolean }) {
  const cardSize = isKioskMode ? 'min-h-[320px]' : 'min-h-[280px]';
  const imageSize = isKioskMode ? 'h-48' : 'h-40';

  return (
    <div className={`bg-white rounded-xl overflow-hidden shadow-sm ${cardSize} flex flex-col`}>
      {/* Image Skeleton */}
      <Skeleton variant="rectangular" className={imageSize} />

      {/* Content Skeleton */}
      <div className="p-4 flex-1 flex flex-col gap-2">
        {/* Title */}
        <Skeleton variant="text" className="mb-2" />
        <Skeleton variant="text" width="70%" />

        <div className="flex-1" />

        {/* Price */}
        <Skeleton variant="text" width="40%" height="24px" className="mb-2" />

        {/* Seller Info */}
        <div className="flex items-center gap-2">
          <Skeleton variant="circular" width="24px" height="24px" />
          <Skeleton variant="text" width="80px" />
        </div>
      </div>
    </div>
  );
}

// Shop Page Skeleton
export function ShopPageSkeleton() {
  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header Skeleton */}
      <div className="bg-white shadow-sm p-4">
        <div className="container mx-auto flex items-center justify-between">
          <Skeleton width="150px" height="32px" />
          <div className="flex items-center gap-3">
            <Skeleton width="80px" height="40px" className="rounded-lg" />
            <Skeleton width="100px" height="40px" className="rounded-lg" />
          </div>
        </div>
      </div>

      {/* Shop Header Skeleton */}
      <div className="bg-gradient-to-br from-blue-50 to-blue-100 py-8">
        <div className="container mx-auto px-4">
          <div className="flex items-center gap-6">
            <Skeleton variant="circular" width="80px" height="80px" />
            <div className="flex-1 space-y-2">
              <Skeleton width="200px" height="32px" />
              <Skeleton width="300px" height="20px" />
              <Skeleton width="150px" height="16px" />
            </div>
          </div>
        </div>
      </div>

      {/* Tabs Skeleton */}
      <div className="bg-white border-b p-4">
        <div className="container mx-auto flex gap-8">
          <Skeleton width="100px" height="40px" />
          <Skeleton width="120px" height="40px" />
        </div>
      </div>

      {/* Product Grid Skeleton */}
      <div className="container mx-auto px-4 py-8">
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {[...Array(10)].map((_, i) => (
            <ProductCardSkeleton key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}

// Product Detail Skeleton
export function ProductDetailSkeleton() {
  return (
    <div className="container mx-auto px-4 py-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Image Gallery Skeleton */}
        <div className="bg-white rounded-xl overflow-hidden">
          <Skeleton variant="rectangular" className="aspect-square" />
          <div className="p-4 grid grid-cols-4 gap-2">
            {[...Array(4)].map((_, i) => (
              <Skeleton key={i} variant="rectangular" className="aspect-square" />
            ))}
          </div>
        </div>

        {/* Product Info Skeleton */}
        <div className="space-y-6">
          <div className="bg-white rounded-xl p-6 space-y-4">
            <div className="flex gap-2">
              <Skeleton width="80px" height="28px" className="rounded-lg" />
              <Skeleton width="100px" height="28px" className="rounded-lg" />
            </div>
            <Skeleton width="80%" height="32px" />
            <Skeleton width="120px" height="40px" />
            <Skeleton width="150px" height="20px" />
          </div>

          <div className="bg-white rounded-xl p-6 space-y-4">
            <Skeleton width="100px" height="24px" />
            <div className="flex items-center gap-4">
              <Skeleton variant="circular" width="64px" height="64px" />
              <div className="flex-1 space-y-2">
                <Skeleton width="120px" height="24px" />
                <Skeleton width="200px" height="16px" />
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl p-6">
            <div className="grid grid-cols-2 gap-3">
              <Skeleton height="48px" className="rounded-lg" />
              <Skeleton height="48px" className="rounded-lg" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
