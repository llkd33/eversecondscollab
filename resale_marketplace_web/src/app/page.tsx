'use client';

import React, { useState, useEffect } from 'react';
import ProductCard from '@/components/ProductCard';
import CategoryFilter from '@/components/CategoryFilter';
import { Product, Category, ProductStatus } from '@/types';

// Mock data - In production, this would come from Supabase
const mockCategories: Category[] = [
  { id: '1', name: '의류', slug: 'clothing' },
  { id: '2', name: '전자기기', slug: 'electronics' },
  { id: '3', name: '생활용품', slug: 'home' },
  { id: '4', name: '스포츠', slug: 'sports' },
  { id: '5', name: '뷰티', slug: 'beauty' },
];

const mockProducts: Product[] = [
  {
    id: '1',
    title: '나이키 운동화 270 리액트',
    price: 85000,
    description: '거의 새 제품입니다. 3번 정도만 착용했어요.',
    images: ['/api/placeholder/400/400'],
    category: mockCategories[3],
    sellerId: 'user1',
    sellerInfo: {
      id: 'user1',
      name: '김철수',
      level: 5,
      rating: 4.8,
      totalTransactions: 42,
      successRate: 98,
    },
    resaleEnabled: true,
    commissionRate: 15,
    status: ProductStatus.ACTIVE,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  {
    id: '2',
    title: '아이패드 프로 11인치 3세대',
    price: 750000,
    description: '박스 풀세트, 애플케어+ 가입',
    images: ['/api/placeholder/400/400'],
    category: mockCategories[1],
    sellerId: 'user2',
    sellerInfo: {
      id: 'user2',
      name: '이영희',
      level: 3,
      rating: 4.5,
      totalTransactions: 15,
      successRate: 95,
    },
    resaleEnabled: true,
    commissionRate: 10,
    status: ProductStatus.ACTIVE,
    createdAt: new Date(),
    updatedAt: new Date(),
  },
  // Add more mock products as needed
];

export default function HomePage() {
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [isKioskMode, setIsKioskMode] = useState(false);
  const [products, setProducts] = useState<Product[]>(mockProducts);
  const [filteredProducts, setFilteredProducts] = useState<Product[]>(mockProducts);

  // Detect kiosk mode (could be based on URL parameter or screen size)
  useEffect(() => {
    const checkKioskMode = () => {
      const urlParams = new URLSearchParams(window.location.search);
      const kioskParam = urlParams.get('kiosk');
      const isTouchDevice = 'ontouchstart' in window;
      const isLargeScreen = window.innerWidth >= 1024;
      
      setIsKioskMode(kioskParam === 'true' || (isTouchDevice && isLargeScreen));
    };

    checkKioskMode();
    window.addEventListener('resize', checkKioskMode);
    return () => window.removeEventListener('resize', checkKioskMode);
  }, []);

  // Filter products
  useEffect(() => {
    let filtered = [...products];

    // Category filter
    if (selectedCategory) {
      filtered = filtered.filter(product => product.category.id === selectedCategory);
    }

    // Search filter
    if (searchQuery) {
      filtered = filtered.filter(product =>
        product.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        product.description.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    setFilteredProducts(filtered);
  }, [selectedCategory, searchQuery, products]);

  return (
    <div className={`min-h-screen bg-gray-50 ${isKioskMode ? 'kiosk-mode' : ''}`}>
      {/* Header */}
      <header className="bg-white shadow-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <h1 className={`font-bold text-blue-600 ${isKioskMode ? 'text-3xl' : 'text-2xl'}`}>
                에버세컨즈
              </h1>
              {isKioskMode && (
                <span className="bg-orange-100 text-orange-700 px-3 py-1 rounded-lg text-sm font-semibold">
                  키오스크 모드
                </span>
              )}
            </div>
            
            {/* Search Bar */}
            <div className="flex-1 max-w-xl mx-8">
              <div className="relative">
                <input
                  type="text"
                  placeholder="상품 검색..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className={`
                    w-full rounded-lg border border-gray-300 bg-gray-50
                    focus:bg-white focus:border-blue-500 focus:outline-none
                    transition-all duration-200
                    ${isKioskMode ? 'px-12 py-4 text-lg' : 'px-10 py-3 text-base'}
                  `}
                />
                <svg
                  className={`absolute left-3 text-gray-400 ${isKioskMode ? 'top-4 w-6 h-6' : 'top-3.5 w-5 h-5'}`}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                  />
                </svg>
              </div>
            </div>

            {/* App Download Button */}
            <button
              onClick={() => {
                // Show QR code modal
                alert('앱 다운로드 QR 코드 표시');
              }}
              className={`
                bg-blue-600 text-white font-medium rounded-lg
                hover:bg-blue-700 transition-colors duration-200
                flex items-center gap-2
                ${isKioskMode ? 'px-6 py-3 text-lg' : 'px-4 py-2 text-base'}
              `}
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
        {/* Category Filter */}
        <CategoryFilter
          categories={mockCategories}
          selectedCategory={selectedCategory}
          onCategorySelect={setSelectedCategory}
          isKioskMode={isKioskMode}
        />

        {/* Product Grid */}
        <div className="mt-6">
          {filteredProducts.length > 0 ? (
            <div className={`
              grid gap-4
              ${isKioskMode 
                ? 'grid-cols-2 lg:grid-cols-3 xl:grid-cols-4' 
                : 'grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5'
              }
            `}>
              {filteredProducts.map((product) => (
                <ProductCard
                  key={product.id}
                  product={product}
                  isKioskMode={isKioskMode}
                />
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
              <p className="text-gray-500 text-lg">검색 결과가 없습니다</p>
            </div>
          )}
        </div>

        {/* Load More Button */}
        {filteredProducts.length > 0 && (
          <div className="mt-8 text-center">
            <button
              className={`
                bg-white border-2 border-gray-300 text-gray-700 font-medium rounded-lg
                hover:bg-gray-50 transition-colors duration-200
                ${isKioskMode ? 'px-8 py-4 text-lg' : 'px-6 py-3 text-base'}
              `}
            >
              더 보기
            </button>
          </div>
        )}
      </main>

      {/* Floating Action Button for Kiosk Mode */}
      {isKioskMode && (
        <button
          onClick={() => {
            // Show help or information
            alert('도움말 표시');
          }}
          className="fixed bottom-8 right-8 bg-blue-600 text-white rounded-full p-4 shadow-lg hover:bg-blue-700 transition-colors duration-200"
        >
          <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
              d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </button>
      )}
    </div>
  );
}
