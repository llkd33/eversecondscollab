'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { transactionService } from '@/lib/supabase/transactions';
import { productService } from '@/lib/supabase/products';
import { userService } from '@/lib/supabase/users';
import { colors } from '@/lib/theme';

interface DashboardStats {
  totalUsers: number;
  totalProducts: number;
  totalTransactions: number;
  pendingTransactions: number;
  completedTransactions: number;
  totalRevenue: number;
  activeDisputes?: number;
}

const initialStats: DashboardStats = {
  totalUsers: 0,
  totalProducts: 0,
  totalTransactions: 0,
  pendingTransactions: 0,
  completedTransactions: 0,
  totalRevenue: 0,
  activeDisputes: 0,
};

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState('overview');
  const [stats, setStats] = useState(initialStats);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Real data states
  const [users, setUsers] = useState<any[]>([]);
  const [products, setProducts] = useState<any[]>([]);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [recentTransactions, setRecentTransactions] = useState<any[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');

  // Load real data from Supabase
  useEffect(() => {
    const loadStats = async () => {
      try {
        setLoading(true);
        setError(null);

        console.log('🔄 Supabase 데이터 로딩 중...');

        // Load stats from services
        const [userStats, productStats, transactionStats] = await Promise.all([
          userService.getAllUsersStats(),
          productService.getProductStats(),
          transactionService.getTransactionStats(),
        ]);

        console.log('✅ 사용자 통계:', userStats);
        console.log('✅ 상품 통계:', productStats);
        console.log('✅ 거래 통계:', transactionStats);

        setStats({
          totalUsers: userStats.total,
          totalProducts: productStats.total,
          totalTransactions: transactionStats.total,
          pendingTransactions: transactionStats.pending,
          completedTransactions: transactionStats.completed,
          totalRevenue: transactionStats.revenue,
          activeDisputes: 0, // TODO: Get from reports table
        });

        // Load recent transactions for overview
        console.log('🔄 최근 거래 데이터 로딩 중...');
        const recentTxData = await transactionService.getTransactions({ limit: 5 });
        console.log('✅ 최근 거래 데이터:', recentTxData);
        setRecentTransactions(recentTxData);

        console.log('✅ Supabase 데이터 로딩 완료!');
      } catch (err: any) {
        console.error('❌ Supabase 데이터 로딩 실패:', err);
        setError(`통계 데이터를 불러오는데 실패했습니다: ${err.message || '알 수 없는 오류'}`);

        // 에러 발생 시 빈 데이터로 설정
        setStats({
          totalUsers: 0,
          totalProducts: 0,
          totalTransactions: 0,
          pendingTransactions: 0,
          completedTransactions: 0,
          totalRevenue: 0,
          activeDisputes: 0,
        });
        setRecentTransactions([]);
      } finally {
        setLoading(false);
      }
    };

    loadStats();
  }, []);

  // Load tab-specific data when switching tabs
  useEffect(() => {
    const loadTabData = async () => {
      try {
        if (activeTab === 'users') {
          console.log('🔄 사용자 데이터 로딩 중...');
          const usersData = await userService.getAllUsers({ limit: 100 });
          console.log('✅ 사용자 데이터:', usersData);
          setUsers(usersData);
        } else if (activeTab === 'products') {
          console.log('🔄 상품 데이터 로딩 중...');
          const productsData = await productService.getProducts({ limit: 100 });
          console.log('✅ 상품 데이터:', productsData);
          setProducts(productsData);
        } else if (activeTab === 'transactions') {
          console.log('🔄 거래 데이터 로딩 중...');
          const transactionsData = await transactionService.getTransactions({ limit: 100 });
          console.log('✅ 거래 데이터:', transactionsData);
          setTransactions(transactionsData);
        }
      } catch (err) {
        console.error('❌ 탭 데이터 로딩 실패:', err);
      }
    };

    if (!loading && activeTab !== 'overview' && activeTab !== 'disputes') {
      loadTabData();
    }
  }, [activeTab, loading]);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW',
    }).format(amount);
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('ko-KR');
  };

  const getStatusBadge = (status: string) => {
    const statusConfig = {
      completed: { bg: 'bg-green-100', text: 'text-green-800', label: '완료' },
      pending: { bg: 'bg-yellow-100', text: 'text-yellow-800', label: '대기' },
      investigating: { bg: 'bg-blue-100', text: 'text-blue-800', label: '조사중' },
      cancelled: { bg: 'bg-red-100', text: 'text-red-800', label: '취소' }
    };
    
    const config = statusConfig[status as keyof typeof statusConfig] || statusConfig.pending;
    
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${config.bg} ${config.text}`}>
        {config.label}
      </span>
    );
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div className="flex items-center">
              <Link href="/" className="text-2xl font-bold text-blue-600 mr-8">
                에버세컨즈
              </Link>
              <h1 className="text-2xl font-semibold text-gray-900">관리자 대시보드</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-500">관리자님, 안녕하세요</span>
              <Link
                href="/admin"
                className="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-2 rounded-md text-sm font-medium transition-colors"
              >
                로그아웃
              </Link>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Navigation Tabs */}
        <div className="border-b border-gray-200 mb-8">
          <nav className="-mb-px flex space-x-8">
            {[
              { id: 'overview', label: '개요', icon: '📊' },
              { id: 'transactions', label: '거래 관리', icon: '💳' },
              { id: 'disputes', label: '분쟁 처리', icon: '⚖️' },
              { id: 'users', label: '사용자 관리', icon: '👥' },
              { id: 'products', label: '상품 관리', icon: '📦' }
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`py-2 px-1 border-b-2 font-medium text-sm flex items-center gap-2 ${
                  activeTab === tab.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <span>{tab.icon}</span>
                {tab.label}
              </button>
            ))}
          </nav>
        </div>

        {/* Loading State */}
        {loading && (
          <div className="flex justify-center items-center py-20">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
          </div>
        )}

        {/* Error State */}
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-6">
            <p>{error}</p>
            <button
              onClick={() => window.location.reload()}
              className="mt-2 text-sm underline"
            >
              다시 시도
            </button>
          </div>
        )}

        {/* Overview Tab */}
        {!loading && !error && activeTab === 'overview' && (
          <div className="space-y-8">
            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-5">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-sm">👥</span>
                      </div>
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">총 사용자</dt>
                        <dd className="text-lg font-medium text-gray-900">{stats.totalUsers.toLocaleString()}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-5">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-sm">💳</span>
                      </div>
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">총 거래</dt>
                        <dd className="text-lg font-medium text-gray-900">{stats.totalTransactions.toLocaleString()}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-5">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-sm">💰</span>
                      </div>
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">총 매출</dt>
                        <dd className="text-lg font-medium text-gray-900">{formatCurrency(stats.totalRevenue)}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-5">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-red-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-sm">⚠️</span>
                      </div>
                    </div>
                    <div className="ml-5 w-0 flex-1">
                      <dl>
                        <dt className="text-sm font-medium text-gray-500 truncate">활성 분쟁</dt>
                        <dd className="text-lg font-medium text-gray-900">{stats.activeDisputes}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Statistics Visualization */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Transaction Status Chart */}
              <div className="bg-white shadow rounded-lg p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">거래 상태</h3>
                <div className="space-y-3">
                  <div>
                    <div className="flex justify-between mb-1">
                      <span className="text-sm font-medium text-gray-700">완료</span>
                      <span className="text-sm font-medium text-gray-900">
                        {stats.completedTransactions}건 ({stats.totalTransactions > 0 ? ((stats.completedTransactions / stats.totalTransactions) * 100).toFixed(1) : 0}%)
                      </span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2.5">
                      <div
                        className="bg-green-600 h-2.5 rounded-full transition-all duration-500"
                        style={{ width: `${stats.totalTransactions > 0 ? (stats.completedTransactions / stats.totalTransactions) * 100 : 0}%` }}
                      ></div>
                    </div>
                  </div>
                  <div>
                    <div className="flex justify-between mb-1">
                      <span className="text-sm font-medium text-gray-700">대기중</span>
                      <span className="text-sm font-medium text-gray-900">
                        {stats.pendingTransactions}건 ({stats.totalTransactions > 0 ? ((stats.pendingTransactions / stats.totalTransactions) * 100).toFixed(1) : 0}%)
                      </span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2.5">
                      <div
                        className="bg-yellow-500 h-2.5 rounded-full transition-all duration-500"
                        style={{ width: `${stats.totalTransactions > 0 ? (stats.pendingTransactions / stats.totalTransactions) * 100 : 0}%` }}
                      ></div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Revenue Summary */}
              <div className="bg-white shadow rounded-lg p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">수익 요약</h3>
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium text-gray-700">총 매출</span>
                    <span className="text-lg font-bold text-green-600">{formatCurrency(stats.totalRevenue)}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium text-gray-700">완료된 거래</span>
                    <span className="text-md font-semibold text-gray-900">{stats.completedTransactions}건</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium text-gray-700">평균 거래액</span>
                    <span className="text-md font-semibold text-gray-900">
                      {formatCurrency(stats.completedTransactions > 0 ? stats.totalRevenue / stats.completedTransactions : 0)}
                    </span>
                  </div>
                </div>
              </div>

              {/* User Statistics */}
              <div className="bg-white shadow rounded-lg p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">사용자 통계</h3>
                <div className="flex items-center justify-center h-48">
                  <div className="text-center">
                    <div className="text-5xl font-bold text-blue-600 mb-2">{stats.totalUsers}</div>
                    <div className="text-sm text-gray-500">총 사용자</div>
                  </div>
                </div>
              </div>

              {/* Product Statistics */}
              <div className="bg-white shadow rounded-lg p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">상품 통계</h3>
                <div className="flex items-center justify-center h-48">
                  <div className="text-center">
                    <div className="text-5xl font-bold text-purple-600 mb-2">{stats.totalProducts}</div>
                    <div className="text-sm text-gray-500">등록된 상품</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Recent Activity */}
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                  최근 거래 ({recentTransactions.length}건)
                </h3>
                {recentTransactions.length === 0 ? (
                  <div className="text-center py-12">
                    <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <p className="mt-2 text-sm text-gray-500">최근 거래가 없습니다</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상품</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">구매자</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">판매자</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">금액</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상태</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">거래일</th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {recentTransactions.map((transaction) => (
                          <tr key={transaction.id}>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              {transaction.product?.title || '상품 정보 없음'}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {transaction.buyer?.name || '알 수 없음'}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {transaction.seller?.name || '알 수 없음'}
                              {transaction.reseller?.name && (
                                <div className="text-xs text-orange-600">대신: {transaction.reseller.name}</div>
                              )}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              {formatCurrency(transaction.price || 0)}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              {getStatusBadge(transaction.status || 'pending')}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {transaction.created_at ? new Date(transaction.created_at).toLocaleDateString('ko-KR') : '-'}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Disputes Tab */}
        {activeTab === 'disputes' && (
          <div className="space-y-6">
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">분쟁 처리</h3>
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">거래 ID</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상품</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">신고자</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">신고 유형</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상태</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">액션</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {mockDisputes.map((dispute) => (
                        <tr key={dispute.id}>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            {dispute.transactionId}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {dispute.productTitle}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {dispute.reporter}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {dispute.type}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            {getStatusBadge(dispute.status)}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                            <button className="text-blue-600 hover:text-blue-900 mr-3">
                              조사하기
                            </button>
                            <button className="text-green-600 hover:text-green-900 mr-3">
                              해결
                            </button>
                            <button className="text-red-600 hover:text-red-900">
                              거부
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Users Tab */}
        {!loading && !error && activeTab === 'users' && (
          <div className="space-y-6">
            {/* Search and Filters */}
            <div className="bg-white shadow rounded-lg p-4">
              <div className="flex gap-4">
                <input
                  type="text"
                  placeholder="이름, 이메일, 전화번호로 검색..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <select
                  value={roleFilter}
                  onChange={(e) => setRoleFilter(e.target.value)}
                  className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="all">모든 역할</option>
                  <option value="일반">일반</option>
                  <option value="대신판매자">대신판매자</option>
                  <option value="관리자">관리자</option>
                </select>
              </div>
            </div>

            {/* Users Table */}
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                  사용자 목록 ({users.length}명)
                </h3>
                {users.length === 0 ? (
                  <div className="text-center py-12">
                    <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                    <p className="mt-2 text-sm text-gray-500">등록된 사용자가 없습니다</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">이름</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">이메일</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">전화번호</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">역할</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">인증</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">가입일</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">액션</th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {users
                          .filter(user => {
                            const matchesSearch = !searchQuery ||
                              user.name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                              user.email?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                              user.phone?.includes(searchQuery);
                            const matchesRole = roleFilter === 'all' || user.role === roleFilter;
                            return matchesSearch && matchesRole;
                          })
                          .map((user) => (
                            <tr key={user.id}>
                              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                {user.name || '미설정'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {user.email || '미설정'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {user.phone || '미설정'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap">
                                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                  user.role === '관리자' ? 'bg-purple-100 text-purple-800' :
                                  user.role === '대신판매자' ? 'bg-orange-100 text-orange-800' :
                                  'bg-gray-100 text-gray-800'
                                }`}>
                                  {user.role || '일반'}
                                </span>
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap">
                                {user.is_verified ? (
                                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                    ✓ 인증됨
                                  </span>
                                ) : (
                                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                    미인증
                                  </span>
                                )}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {user.created_at ? new Date(user.created_at).toLocaleDateString('ko-KR') : '-'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                <button
                                  onClick={async () => {
                                    const newRole = prompt('새 역할을 선택하세요:\n1: 일반\n2: 대신판매자\n3: 관리자');
                                    if (newRole) {
                                      const roleMap: any = { '1': '일반', '2': '대신판매자', '3': '관리자' };
                                      try {
                                        await userService.updateUserRole(user.id, roleMap[newRole]);
                                        alert('역할이 변경되었습니다.');
                                        window.location.reload();
                                      } catch (err) {
                                        alert('역할 변경 실패');
                                      }
                                    }
                                  }}
                                  className="text-blue-600 hover:text-blue-900 mr-3"
                                >
                                  역할 변경
                                </button>
                                <button
                                  onClick={async () => {
                                    try {
                                      await userService.verifyUser(user.id, !user.is_verified);
                                      alert(`${!user.is_verified ? '인증' : '인증 해제'}되었습니다.`);
                                      window.location.reload();
                                    } catch (err) {
                                      alert('인증 상태 변경 실패');
                                    }
                                  }}
                                  className="text-green-600 hover:text-green-900"
                                >
                                  {user.is_verified ? '인증 해제' : '인증'}
                                </button>
                              </td>
                            </tr>
                          ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Products Tab */}
        {!loading && !error && activeTab === 'products' && (
          <div className="space-y-6">
            {/* Search and Filters */}
            <div className="bg-white shadow rounded-lg p-4">
              <div className="flex gap-4">
                <input
                  type="text"
                  placeholder="상품명으로 검색..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="all">모든 상태</option>
                  <option value="판매중">판매중</option>
                  <option value="판매완료">판매완료</option>
                  <option value="예약중">예약중</option>
                </select>
              </div>
            </div>

            {/* Products Table */}
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                  상품 목록 ({products.length}개)
                </h3>
                {products.length === 0 ? (
                  <div className="text-center py-12">
                    <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                    </svg>
                    <p className="mt-2 text-sm text-gray-500">등록된 상품이 없습니다</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상품명</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">가격</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">판매자</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">카테고리</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상태</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">대신팔기</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">등록일</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">액션</th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {products
                          .filter(product => {
                            const matchesSearch = !searchQuery ||
                              product.title?.toLowerCase().includes(searchQuery.toLowerCase());
                            const matchesStatus = statusFilter === 'all' || product.status === statusFilter;
                            return matchesSearch && matchesStatus;
                          })
                          .map((product) => (
                            <tr key={product.id}>
                              <td className="px-6 py-4 whitespace-nowrap">
                                <div className="flex items-center">
                                  <div className="h-10 w-10 flex-shrink-0">
                                    {product.images && product.images[0] ? (
                                      <img className="h-10 w-10 rounded object-cover" src={product.images[0]} alt="" />
                                    ) : (
                                      <div className="h-10 w-10 rounded bg-gray-200 flex items-center justify-center">
                                        <svg className="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                        </svg>
                                      </div>
                                    )}
                                  </div>
                                  <div className="ml-4">
                                    <div className="text-sm font-medium text-gray-900">{product.title}</div>
                                  </div>
                                </div>
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                {formatCurrency(product.price)}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {product.seller?.name || '알 수 없음'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {product.category || '-'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap">
                                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                  product.status === '판매중' ? 'bg-green-100 text-green-800' :
                                  product.status === '판매완료' ? 'bg-gray-100 text-gray-800' :
                                  'bg-yellow-100 text-yellow-800'
                                }`}>
                                  {product.status || '판매중'}
                                </span>
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-center">
                                {product.resale_enabled ? (
                                  <span className="text-orange-600 font-medium">✓</span>
                                ) : (
                                  <span className="text-gray-300">-</span>
                                )}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {product.created_at ? new Date(product.created_at).toLocaleDateString('ko-KR') : '-'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                <button
                                  onClick={async () => {
                                    const newStatus = prompt('상태 변경:\n1: 판매중\n2: 판매완료\n3: 예약중');
                                    if (newStatus) {
                                      const statusMap: any = { '1': '판매중', '2': '판매완료', '3': '예약중' };
                                      try {
                                        await productService.updateProduct(product.id, { status: statusMap[newStatus] });
                                        alert('상태가 변경되었습니다.');
                                        window.location.reload();
                                      } catch (err) {
                                        alert('상태 변경 실패');
                                      }
                                    }
                                  }}
                                  className="text-blue-600 hover:text-blue-900 mr-3"
                                >
                                  상태 변경
                                </button>
                                <button
                                  onClick={async () => {
                                    if (confirm('이 상품을 삭제하시겠습니까?')) {
                                      try {
                                        await productService.deleteProduct(product.id);
                                        alert('상품이 삭제되었습니다.');
                                        window.location.reload();
                                      } catch (err) {
                                        alert('삭제 실패');
                                      }
                                    }
                                  }}
                                  className="text-red-600 hover:text-red-900"
                                >
                                  삭제
                                </button>
                              </td>
                            </tr>
                          ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Transactions Tab */}
        {!loading && !error && activeTab === 'transactions' && (
          <div className="space-y-6">
            {/* Search and Filters */}
            <div className="bg-white shadow rounded-lg p-4">
              <div className="flex gap-4">
                <input
                  type="text"
                  placeholder="거래 ID, 상품명으로 검색..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="all">모든 상태</option>
                  <option value="pending">대기</option>
                  <option value="completed">완료</option>
                  <option value="cancelled">취소</option>
                </select>
              </div>
            </div>

            {/* Transactions Table */}
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                  거래 목록 ({transactions.length}건)
                </h3>
                {transactions.length === 0 ? (
                  <div className="text-center py-12">
                    <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <p className="mt-2 text-sm text-gray-500">등록된 거래가 없습니다</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">ID</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상품</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">구매자</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">판매자</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">대신판매자</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">금액</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">수수료</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상태</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">거래일</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">액션</th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {transactions
                          .filter(tx => {
                            const matchesSearch = !searchQuery ||
                              tx.id?.toLowerCase().includes(searchQuery.toLowerCase()) ||
                              tx.product?.title?.toLowerCase().includes(searchQuery.toLowerCase());
                            const matchesStatus = statusFilter === 'all' || tx.status === statusFilter;
                            return matchesSearch && matchesStatus;
                          })
                          .map((tx) => (
                            <tr key={tx.id}>
                              <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-500">
                                {tx.id?.substring(0, 8)}...
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                {tx.product?.title || '상품 정보 없음'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {tx.buyer?.name || '알 수 없음'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {tx.seller?.name || '알 수 없음'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-orange-600">
                                {tx.reseller?.name || '-'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">
                                {formatCurrency(tx.price || 0)}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {tx.commission_rate ? `${tx.commission_rate}%` : '-'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap">
                                {getStatusBadge(tx.status || 'pending')}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {tx.created_at ? new Date(tx.created_at).toLocaleDateString('ko-KR') : '-'}
                              </td>
                              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                <button
                                  onClick={async () => {
                                    const newStatus = prompt('상태 변경:\n1: pending (대기)\n2: completed (완료)\n3: cancelled (취소)');
                                    if (newStatus) {
                                      const statusMap: any = { '1': 'pending', '2': 'completed', '3': 'cancelled' };
                                      try {
                                        await transactionService.updateTransactionStatus(tx.id, statusMap[newStatus]);
                                        alert('상태가 변경되었습니다.');
                                        window.location.reload();
                                      } catch (err) {
                                        alert('상태 변경 실패');
                                      }
                                    }
                                  }}
                                  className="text-blue-600 hover:text-blue-900"
                                >
                                  상태 변경
                                </button>
                              </td>
                            </tr>
                          ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}