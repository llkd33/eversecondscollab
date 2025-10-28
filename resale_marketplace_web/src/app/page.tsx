'use client';

import React, { useState, useEffect } from 'react';
import ProductCard from '@/components/ProductCard';
import CategoryFilter from '@/components/CategoryFilter';
import { Product, Category, ProductStatus } from '@/types';
import { productService } from '@/lib/supabase/products';
import { colors } from '@/lib/theme';

export default function HomePage() {
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [isKioskMode, setIsKioskMode] = useState(false);
  const [categories, setCategories] = useState<Category[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [filteredProducts, setFilteredProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load categories and products from Supabase
  useEffect(() => {
    const loadData = async () => {
      try {
        setLoading(true);
        setError(null);

        // Load categories
        const categoriesData = await productService.getCategories();
        setCategories(categoriesData);

        // Load products
        const productsData = await productService.getProducts({
          status: ProductStatus.ACTIVE,
          limit: 50,
        });
        setProducts(productsData);
        setFilteredProducts(productsData);
      } catch (err) {
        console.error('Error loading data:', err);
        setError('데이터를 불러오는데 실패했습니다.');
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

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
              <h1
                className={`font-bold ${isKioskMode ? 'text-3xl' : 'text-2xl'}`}
                style={{ color: colors.primary }}
              >
                에버세컨즈
              </h1>
              {isKioskMode && (
                <span
                  className="px-3 py-1 rounded-lg text-sm font-semibold text-white"
                  style={{ backgroundColor: colors.accent }}
                >
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
                text-white font-medium rounded-lg
                transition-colors duration-200
                flex items-center gap-2
                ${isKioskMode ? 'px-6 py-3 text-lg' : 'px-4 py-2 text-base'}
              `}
              style={{
                backgroundColor: colors.secondary,
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = colors.secondaryDark;
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = colors.secondary;
              }}
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
        {/* Loading State */}
        {loading && (
          <div className="flex justify-center items-center py-20">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2" style={{ borderColor: colors.primary }}></div>
          </div>
        )}

        {/* Error State */}
        {error && (
          <div className="text-center py-16">
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
            <p className="text-gray-700 text-lg mb-4">{error}</p>
            <button
              onClick={() => window.location.reload()}
              className="px-4 py-2 rounded-lg text-white font-medium"
              style={{ backgroundColor: colors.primary }}
            >
              다시 시도
            </button>
          </div>
        )}

        {/* Content */}
        {!loading && !error && (
          <>
            {/* Category Filter */}
            <CategoryFilter
              categories={categories}
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
                  <p className="text-gray-500 text-lg">
                    {products.length === 0 ? '등록된 상품이 없습니다' : '검색 결과가 없습니다'}
                  </p>
                </div>
              )}
            </div>

            {/* Load More Button */}
            {filteredProducts.length > 0 && products.length >= 50 && (
              <div className="mt-8 text-center">
                <button
                  className={`
                    bg-white font-medium rounded-lg
                    transition-colors duration-200
                    ${isKioskMode ? 'px-8 py-4 text-lg' : 'px-6 py-3 text-base'}
                  `}
                  style={{
                    border: `2px solid ${colors.primary}`,
                    color: colors.primary,
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = colors.primaryLight;
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = 'white';
                  }}
                >
                  더 보기
                </button>
              </div>
            )}
          </>
        )}
      </main>

      {/* Floating Action Button for Kiosk Mode */}
      {isKioskMode && (
        <button
          onClick={() => {
            // Show help or information
            alert('도움말 표시');
          }}
          className="fixed bottom-8 right-8 text-white rounded-full p-4 shadow-lg transition-colors duration-200"
          style={{
            backgroundColor: colors.secondary,
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = colors.secondaryDark;
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = colors.secondary;
          }}
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
