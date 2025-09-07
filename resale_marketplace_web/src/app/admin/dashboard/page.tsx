'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase/config';
import { safeTransactionAdminService, SafeTransaction, SafeTransactionStats } from '@/lib/services/safeTransactionAdminService';

// Mock data - In production, this would come from Supabase
const mockStats = {
  totalUsers: 1247,
  totalSellers: 342,
  totalResellers: 156,
  totalProducts: 2834,
  totalTransactions: 1892,
  totalRevenue: 45670000,
  monthlyGrowth: 12.5,
  activeDisputes: 8
};

const mockRecentTransactions = [
  {
    id: '1',
    productTitle: '나이키 운동화 270 리액트',
    buyer: '김구매',
    seller: '이판매',
    reseller: '박대신',
    amount: 85000,
    commission: 12750,
    status: 'completed',
    createdAt: new Date('2024-03-15')
  },
  {
    id: '2',
    productTitle: '아이패드 프로 11인치',
    buyer: '최구매',
    seller: '정판매',
    reseller: null,
    amount: 750000,
    commission: 0,
    status: 'pending',
    createdAt: new Date('2024-03-14')
  }
];

const mockDisputes = [
  {
    id: '1',
    transactionId: 'TXN-001',
    productTitle: '삼성 갤럭시 버즈',
    reporter: '김신고',
    reportedUser: '이사기',
    type: '미배송',
    status: 'pending',
    createdAt: new Date('2024-03-13')
  },
  {
    id: '2',
    transactionId: 'TXN-002',
    productTitle: '애플워치 시리즈 8',
    reporter: '박피해',
    reportedUser: '최사기',
    type: '상품불일치',
    status: 'investigating',
    createdAt: new Date('2024-03-12')
  }
];

const mockSafeTransactions = [
  {
    id: 'ST-001',
    transactionId: 'TXN-003',
    productTitle: '아이폰 14 프로',
    buyerName: '김구매',
    buyerPhone: '010-1234-5678',
    sellerName: '이판매',
    sellerPhone: '010-2345-6789',
    resellerName: '박대신',
    depositAmount: 1200000,
    depositConfirmed: false,
    shippingConfirmed: false,
    deliveryConfirmed: false,
    settlementStatus: '대기중',
    currentStep: '입금 대기중',
    progress: 0,
    adminNotes: '입금확인 요청됨 - 2024-03-15T10:30:00Z',
    createdAt: new Date('2024-03-15T10:30:00Z'),
    updatedAt: new Date('2024-03-15T10:30:00Z')
  },
  {
    id: 'ST-002',
    transactionId: 'TXN-004',
    productTitle: '맥북 프로 16인치',
    buyerName: '최구매',
    buyerPhone: '010-3456-7890',
    sellerName: '정판매',
    sellerPhone: '010-4567-8901',
    resellerName: null,
    depositAmount: 2500000,
    depositConfirmed: true,
    shippingConfirmed: false,
    deliveryConfirmed: false,
    settlementStatus: '대기중',
    currentStep: '배송 준비중',
    progress: 0.2,
    adminNotes: '입금 확인 완료',
    createdAt: new Date('2024-03-14T14:20:00Z'),
    updatedAt: new Date('2024-03-15T09:15:00Z')
  },
  {
    id: 'ST-003',
    transactionId: 'TXN-005',
    productTitle: '에어팟 프로 2세대',
    buyerName: '박구매',
    buyerPhone: '010-5678-9012',
    sellerName: '김판매',
    sellerPhone: '010-6789-0123',
    resellerName: '이대신',
    depositAmount: 280000,
    depositConfirmed: true,
    shippingConfirmed: true,
    deliveryConfirmed: false,
    settlementStatus: '대기중',
    currentStep: '배송중',
    progress: 0.4,
    adminNotes: '배송 시작 - 운송장: 1234567890',
    createdAt: new Date('2024-03-13T16:45:00Z'),
    updatedAt: new Date('2024-03-14T11:30:00Z')
  },
  {
    id: 'ST-004',
    transactionId: 'TXN-006',
    productTitle: '갤럭시 탭 S9',
    buyerName: '조구매',
    buyerPhone: '010-7890-1234',
    sellerName: '윤판매',
    sellerPhone: '010-8901-2345',
    resellerName: null,
    depositAmount: 650000,
    depositConfirmed: true,
    shippingConfirmed: true,
    deliveryConfirmed: true,
    settlementStatus: '정산준비',
    currentStep: '정산 준비중',
    progress: 0.8,
    adminNotes: '거래 정상 완료 - 정산 처리 필요',
    createdAt: new Date('2024-03-12T09:20:00Z'),
    updatedAt: new Date('2024-03-15T08:45:00Z')
  }
];

const mockSafeTransactionStats = {
  totalCount: 24,
  waitingDepositCount: 3,
  waitingShippingCount: 5,
  shippingCount: 8,
  waitingSettlementCount: 6,
  completedCount: 2
};

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState('overview');
  const [selectedSafeTransaction, setSelectedSafeTransaction] = useState<SafeTransaction | null>(null);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [safeTransactions, setSafeTransactions] = useState<SafeTransaction[]>([]);
  const [safeTransactionStats, setSafeTransactionStats] = useState<SafeTransactionStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [statusFilter, setStatusFilter] = useState('');
  const router = useRouter();

  useEffect(() => {
    const checkSession = async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) {
        router.replace('/admin');
        return;
      }
      try {
        const userId = data.session.user.id;
        const { data: user, error } = await supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
        if (error) throw error;
        if (!user || user.role !== '관리자') {
          alert('관리자 권한이 필요합니다.');
          router.replace('/admin');
        }
      } catch (e) {
        router.replace('/admin');
      }
    };
    checkSession();
  }, [router]);

  // Load safe transaction data when tab changes
  useEffect(() => {
    if (activeTab === 'safe-transactions') {
      loadSafeTransactionData();
    }
  }, [activeTab, statusFilter]);

  const loadSafeTransactionData = async () => {
    setLoading(true);
    try {
      // Load stats and transactions in parallel
      const [stats, transactions] = await Promise.all([
        safeTransactionAdminService.getStatsDirectly(),
        safeTransactionAdminService.getListDirectly(statusFilter || undefined)
      ]);
      
      setSafeTransactionStats(stats);
      setSafeTransactions(transactions);
    } catch (error) {
      console.error('Error loading safe transaction data:', error);
      alert('데이터를 불러오는 중 오류가 발생했습니다.');
    } finally {
      setLoading(false);
    }
  };

  const refreshData = () => {
    if (activeTab === 'safe-transactions') {
      loadSafeTransactionData();
    }
  };

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

  // Safe Transaction Handlers
  const handleConfirmDeposit = async (safeTransactionId: string) => {
    if (!confirm('입금을 확인하시겠습니까? 판매자와 대신판매자에게 SMS가 발송됩니다.')) {
      return;
    }
    
    try {
      await safeTransactionAdminService.confirmDeposit(safeTransactionId);
      alert('입금이 확인되었습니다. 관련자들에게 SMS가 발송되었습니다.');
      refreshData();
    } catch (error) {
      alert('입금 확인 중 오류가 발생했습니다.');
      console.error('Error confirming deposit:', error);
    }
  };

  const handleConfirmShipping = async (safeTransactionId: string) => {
    const trackingNumber = prompt('운송장 번호를 입력하세요 (선택사항):');
    const courier = prompt('택배사를 입력하세요 (선택사항):');
    
    try {
      await safeTransactionAdminService.confirmShipping(safeTransactionId, trackingNumber || undefined, courier || undefined);
      alert('배송이 확인되었습니다. 구매자에게 SMS가 발송되었습니다.');
      refreshData();
    } catch (error) {
      alert('배송 확인 중 오류가 발생했습니다.');
      console.error('Error confirming shipping:', error);
    }
  };

  const handleProcessSettlement = async (safeTransactionId: string) => {
    if (!confirm('정산을 처리하시겠습니까? 이 작업은 되돌릴 수 없습니다.')) {
      return;
    }
    
    const adminNotes = prompt('정산 처리 메모를 입력하세요 (선택사항):');
    
    try {
      await safeTransactionAdminService.processSettlement(safeTransactionId, adminNotes || undefined);
      alert('정산이 완료되었습니다.');
      refreshData();
    } catch (error) {
      alert('정산 처리 중 오류가 발생했습니다.');
      console.error('Error processing settlement:', error);
    }
  };

  const handleViewDetails = (safeTransactionId: string) => {
    const transaction = safeTransactions.find(t => t.id === safeTransactionId);
    if (transaction) {
      setSelectedSafeTransaction(transaction);
      setShowDetailModal(true);
    }
  };

  const handleUpdateNotes = async (safeTransactionId: string, currentNotes: string) => {
    const newNotes = prompt('관리자 메모를 입력하세요:', currentNotes || '');
    if (newNotes !== null && newNotes !== currentNotes) {
      try {
        await safeTransactionAdminService.updateNotes(safeTransactionId, newNotes);
        alert('메모가 업데이트되었습니다.');
        refreshData();
        setShowDetailModal(false);
      } catch (error) {
        alert('메모 업데이트 중 오류가 발생했습니다.');
        console.error('Error updating notes:', error);
      }
    }
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
              <button
                onClick={async () => {
                  await supabase.auth.signOut();
                  router.replace('/admin');
                }}
                className="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-2 rounded-md text-sm font-medium transition-colors"
              >
                로그아웃
              </button>
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
              { id: 'safe-transactions', label: '안전거래 관리', icon: '🔒' },
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

        {/* Overview Tab */}
        {activeTab === 'overview' && (
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
                        <dd className="text-lg font-medium text-gray-900">{mockStats.totalUsers.toLocaleString()}</dd>
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
                        <dd className="text-lg font-medium text-gray-900">{mockStats.totalTransactions.toLocaleString()}</dd>
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
                        <dd className="text-lg font-medium text-gray-900">{formatCurrency(mockStats.totalRevenue)}</dd>
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
                        <dd className="text-lg font-medium text-gray-900">{mockStats.activeDisputes}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Recent Activity */}
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">최근 거래</h3>
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상품</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">구매자</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">판매자</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">금액</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">상태</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {mockRecentTransactions.map((transaction) => (
                        <tr key={transaction.id}>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            {transaction.productTitle}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {transaction.buyer}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {transaction.seller}
                            {transaction.reseller && (
                              <div className="text-xs text-orange-600">대신: {transaction.reseller}</div>
                            )}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {formatCurrency(transaction.amount)}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            {getStatusBadge(transaction.status)}
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

        {/* Safe Transactions Tab */}
        {activeTab === 'safe-transactions' && (
          <div className="space-y-6">
            {/* Safe Transaction Stats */}
            <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4">
              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-4">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-xs">📊</span>
                      </div>
                    </div>
                    <div className="ml-3 w-0 flex-1">
                      <dl>
                        <dt className="text-xs font-medium text-gray-500 truncate">전체</dt>
                        <dd className="text-lg font-medium text-gray-900">{safeTransactionStats?.totalCount || 0}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-4">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-xs">💰</span>
                      </div>
                    </div>
                    <div className="ml-3 w-0 flex-1">
                      <dl>
                        <dt className="text-xs font-medium text-gray-500 truncate">입금대기</dt>
                        <dd className="text-lg font-medium text-gray-900">{safeTransactionStats?.waitingDepositCount || 0}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-4">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-orange-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-xs">📦</span>
                      </div>
                    </div>
                    <div className="ml-3 w-0 flex-1">
                      <dl>
                        <dt className="text-xs font-medium text-gray-500 truncate">배송준비</dt>
                        <dd className="text-lg font-medium text-gray-900">{safeTransactionStats?.waitingShippingCount || 0}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-4">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-blue-600 rounded-md flex items-center justify-center">
                        <span className="text-white text-xs">🚚</span>
                      </div>
                    </div>
                    <div className="ml-3 w-0 flex-1">
                      <dl>
                        <dt className="text-xs font-medium text-gray-500 truncate">배송중</dt>
                        <dd className="text-lg font-medium text-gray-900">{safeTransactionStats?.shippingCount || 0}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-4">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-purple-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-xs">⏳</span>
                      </div>
                    </div>
                    <div className="ml-3 w-0 flex-1">
                      <dl>
                        <dt className="text-xs font-medium text-gray-500 truncate">정산대기</dt>
                        <dd className="text-lg font-medium text-gray-900">{safeTransactionStats?.waitingSettlementCount || 0}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-white overflow-hidden shadow rounded-lg">
                <div className="p-4">
                  <div className="flex items-center">
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                        <span className="text-white text-xs">✅</span>
                      </div>
                    </div>
                    <div className="ml-3 w-0 flex-1">
                      <dl>
                        <dt className="text-xs font-medium text-gray-500 truncate">완료</dt>
                        <dd className="text-lg font-medium text-gray-900">{safeTransactionStats?.completedCount || 0}</dd>
                      </dl>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Safe Transactions List */}
            <div className="bg-white shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-lg leading-6 font-medium text-gray-900">안전거래 관리</h3>
                  <div className="flex space-x-2">
                    <select 
                      className="border border-gray-300 rounded-md px-3 py-2 text-sm"
                      value={statusFilter}
                      onChange={(e) => setStatusFilter(e.target.value)}
                    >
                      <option value="">전체 상태</option>
                      <option value="대기중">입금 대기중</option>
                      <option value="정산준비">정산 준비중</option>
                      <option value="정산완료">정산 완료</option>
                    </select>
                    <button 
                      className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium disabled:opacity-50"
                      onClick={refreshData}
                      disabled={loading}
                    >
                      {loading ? '로딩중...' : '새로고침'}
                    </button>
                  </div>
                </div>
                
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">거래 정보</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">참여자</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">금액</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">진행 상태</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">관리자 메모</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">액션</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {loading ? (
                        <tr>
                          <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                            데이터를 불러오는 중...
                          </td>
                        </tr>
                      ) : safeTransactions.length === 0 ? (
                        <tr>
                          <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                            안전거래 데이터가 없습니다.
                          </td>
                        </tr>
                      ) : (
                        safeTransactions.map((safeTransaction) => (
                        <tr key={safeTransaction.id} className="hover:bg-gray-50">
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="text-sm font-medium text-gray-900">{safeTransaction.productTitle}</div>
                            <div className="text-sm text-gray-500">ID: {safeTransaction.transactionId}</div>
                            <div className="text-xs text-gray-400">{formatDate(safeTransaction.createdAt)}</div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="text-sm text-gray-900">
                              <div>구매: {safeTransaction.buyerName}</div>
                              <div className="text-xs text-gray-500">{safeTransaction.buyerPhone}</div>
                            </div>
                            <div className="text-sm text-gray-900 mt-1">
                              <div>판매: {safeTransaction.sellerName}</div>
                              <div className="text-xs text-gray-500">{safeTransaction.sellerPhone}</div>
                            </div>
                            {safeTransaction.resellerName && (
                              <div className="text-sm text-orange-600 mt-1">
                                <div>대신: {safeTransaction.resellerName}</div>
                              </div>
                            )}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="text-sm font-medium text-gray-900">
                              {formatCurrency(safeTransaction.depositAmount)}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex flex-col space-y-2">
                              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                safeTransaction.currentStep === '입금 대기중' ? 'bg-yellow-100 text-yellow-800' :
                                safeTransaction.currentStep === '배송 준비중' ? 'bg-orange-100 text-orange-800' :
                                safeTransaction.currentStep === '배송중' ? 'bg-blue-100 text-blue-800' :
                                safeTransaction.currentStep === '정산 준비중' ? 'bg-purple-100 text-purple-800' :
                                'bg-green-100 text-green-800'
                              }`}>
                                {safeTransaction.currentStep}
                              </span>
                              <div className="w-full bg-gray-200 rounded-full h-2">
                                <div 
                                  className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                                  style={{ width: `${safeTransaction.progress * 100}%` }}
                                ></div>
                              </div>
                              <span className="text-xs text-gray-500">{Math.round(safeTransaction.progress * 100)}%</span>
                            </div>
                          </td>
                          <td className="px-6 py-4">
                            <div className="text-sm text-gray-500 max-w-xs truncate">
                              {safeTransaction.adminNotes || '메모 없음'}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                            <div className="flex flex-col space-y-1">
                              {!safeTransaction.depositConfirmed && (
                                <button 
                                  className="text-green-600 hover:text-green-900 text-xs bg-green-50 hover:bg-green-100 px-2 py-1 rounded"
                                  onClick={() => handleConfirmDeposit(safeTransaction.id)}
                                >
                                  입금확인
                                </button>
                              )}
                              {safeTransaction.depositConfirmed && !safeTransaction.shippingConfirmed && (
                                <button 
                                  className="text-blue-600 hover:text-blue-900 text-xs bg-blue-50 hover:bg-blue-100 px-2 py-1 rounded"
                                  onClick={() => handleConfirmShipping(safeTransaction.id)}
                                >
                                  배송확인
                                </button>
                              )}
                              {safeTransaction.settlementStatus === '정산준비' && (
                                <button 
                                  className="text-purple-600 hover:text-purple-900 text-xs bg-purple-50 hover:bg-purple-100 px-2 py-1 rounded"
                                  onClick={() => handleProcessSettlement(safeTransaction.id)}
                                >
                                  정산처리
                                </button>
                              )}
                              <button 
                                className="text-gray-600 hover:text-gray-900 text-xs bg-gray-50 hover:bg-gray-100 px-2 py-1 rounded"
                                onClick={() => handleViewDetails(safeTransaction.id)}
                              >
                                상세보기
                              </button>
                            </div>
                          </td>
                        </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
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

        {/* Other tabs would be implemented similarly */}
        {activeTab === 'transactions' && (
          <div className="bg-white shadow rounded-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-4">거래 관리</h3>
            <p className="text-gray-500">거래 관리 기능이 여기에 구현됩니다.</p>
          </div>
        )}

        {activeTab === 'users' && (
          <div className="bg-white shadow rounded-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-4">사용자 관리</h3>
            <p className="text-gray-500">사용자 관리 기능이 여기에 구현됩니다.</p>
          </div>
        )}

        {activeTab === 'products' && (
          <div className="bg-white shadow rounded-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-4">상품 관리</h3>
            <p className="text-gray-500">상품 및 카테고리 관리 기능이 여기에 구현됩니다.</p>
          </div>
        )}
      </div>

      {/* Safe Transaction Detail Modal */}
      {showDetailModal && selectedSafeTransaction && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-11/12 max-w-4xl shadow-lg rounded-md bg-white">
            <div className="mt-3">
              {/* Modal Header */}
              <div className="flex justify-between items-center pb-4 border-b">
                <h3 className="text-lg font-medium text-gray-900">
                  안전거래 상세 정보 - {selectedSafeTransaction.transactionId}
                </h3>
                <button
                  onClick={() => setShowDetailModal(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <span className="sr-only">닫기</span>
                  <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              {/* Modal Content */}
              <div className="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Left Column - Transaction Info */}
                <div className="space-y-6">
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-3">거래 정보</h4>
                    <dl className="space-y-2">
                      <div className="flex justify-between">
                        <dt className="text-sm text-gray-500">상품명:</dt>
                        <dd className="text-sm font-medium text-gray-900">{selectedSafeTransaction.productTitle}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-sm text-gray-500">거래 ID:</dt>
                        <dd className="text-sm text-gray-900">{selectedSafeTransaction.transactionId}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-sm text-gray-500">입금 금액:</dt>
                        <dd className="text-sm font-medium text-gray-900">{formatCurrency(selectedSafeTransaction.depositAmount)}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-sm text-gray-500">생성일:</dt>
                        <dd className="text-sm text-gray-900">{formatDate(selectedSafeTransaction.createdAt)}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-sm text-gray-500">최종 업데이트:</dt>
                        <dd className="text-sm text-gray-900">{formatDate(selectedSafeTransaction.updatedAt)}</dd>
                      </div>
                    </dl>
                  </div>

                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-3">참여자 정보</h4>
                    <div className="space-y-3">
                      <div className="border-l-4 border-blue-400 pl-3">
                        <div className="text-sm font-medium text-gray-900">구매자</div>
                        <div className="text-sm text-gray-600">{selectedSafeTransaction.buyerName}</div>
                        <div className="text-sm text-gray-500">{selectedSafeTransaction.buyerPhone}</div>
                      </div>
                      <div className="border-l-4 border-green-400 pl-3">
                        <div className="text-sm font-medium text-gray-900">판매자</div>
                        <div className="text-sm text-gray-600">{selectedSafeTransaction.sellerName}</div>
                        <div className="text-sm text-gray-500">{selectedSafeTransaction.sellerPhone}</div>
                      </div>
                      {selectedSafeTransaction.resellerName && (
                        <div className="border-l-4 border-orange-400 pl-3">
                          <div className="text-sm font-medium text-gray-900">대신판매자</div>
                          <div className="text-sm text-gray-600">{selectedSafeTransaction.resellerName}</div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>

                {/* Right Column - Progress & Actions */}
                <div className="space-y-6">
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-3">진행 상태</h4>
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="text-sm text-gray-600">현재 단계</span>
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                          selectedSafeTransaction.currentStep === '입금 대기중' ? 'bg-yellow-100 text-yellow-800' :
                          selectedSafeTransaction.currentStep === '배송 준비중' ? 'bg-orange-100 text-orange-800' :
                          selectedSafeTransaction.currentStep === '배송중' ? 'bg-blue-100 text-blue-800' :
                          selectedSafeTransaction.currentStep === '정산 준비중' ? 'bg-purple-100 text-purple-800' :
                          'bg-green-100 text-green-800'
                        }`}>
                          {selectedSafeTransaction.currentStep}
                        </span>
                      </div>
                      
                      <div>
                        <div className="flex justify-between text-sm mb-1">
                          <span className="text-gray-600">진행률</span>
                          <span className="text-gray-900">{Math.round(selectedSafeTransaction.progress * 100)}%</span>
                        </div>
                        <div className="w-full bg-gray-200 rounded-full h-2">
                          <div 
                            className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                            style={{ width: `${selectedSafeTransaction.progress * 100}%` }}
                          ></div>
                        </div>
                      </div>

                      {/* Progress Steps */}
                      <div className="space-y-2">
                        <div className={`flex items-center space-x-2 ${selectedSafeTransaction.depositConfirmed ? 'text-green-600' : 'text-gray-400'}`}>
                          <div className={`w-4 h-4 rounded-full ${selectedSafeTransaction.depositConfirmed ? 'bg-green-500' : 'bg-gray-300'}`}></div>
                          <span className="text-sm">입금 확인</span>
                        </div>
                        <div className={`flex items-center space-x-2 ${selectedSafeTransaction.shippingConfirmed ? 'text-green-600' : 'text-gray-400'}`}>
                          <div className={`w-4 h-4 rounded-full ${selectedSafeTransaction.shippingConfirmed ? 'bg-green-500' : 'bg-gray-300'}`}></div>
                          <span className="text-sm">배송 시작</span>
                        </div>
                        <div className={`flex items-center space-x-2 ${selectedSafeTransaction.deliveryConfirmed ? 'text-green-600' : 'text-gray-400'}`}>
                          <div className={`w-4 h-4 rounded-full ${selectedSafeTransaction.deliveryConfirmed ? 'bg-green-500' : 'bg-gray-300'}`}></div>
                          <span className="text-sm">배송 완료</span>
                        </div>
                        <div className={`flex items-center space-x-2 ${selectedSafeTransaction.settlementStatus === '정산준비' ? 'text-orange-600' : selectedSafeTransaction.settlementStatus === '정산완료' ? 'text-green-600' : 'text-gray-400'}`}>
                          <div className={`w-4 h-4 rounded-full ${selectedSafeTransaction.settlementStatus === '정산완료' ? 'bg-green-500' : selectedSafeTransaction.settlementStatus === '정산준비' ? 'bg-orange-500' : 'bg-gray-300'}`}></div>
                          <span className="text-sm">정산 완료</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-3">관리자 메모</h4>
                    <div className="text-sm text-gray-600 bg-white p-3 rounded border min-h-[100px]">
                      {selectedSafeTransaction.adminNotes || '메모가 없습니다.'}
                    </div>
                  </div>

                  {/* Action Buttons */}
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-3">관리 액션</h4>
                    <div className="space-y-2">
                      {!selectedSafeTransaction.depositConfirmed && (
                        <button 
                          className="w-full bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                          onClick={() => {
                            setShowDetailModal(false);
                            handleConfirmDeposit(selectedSafeTransaction.id);
                          }}
                        >
                          입금 확인 처리
                        </button>
                      )}
                      {selectedSafeTransaction.depositConfirmed && !selectedSafeTransaction.shippingConfirmed && (
                        <button 
                          className="w-full bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                          onClick={() => {
                            setShowDetailModal(false);
                            handleConfirmShipping(selectedSafeTransaction.id);
                          }}
                        >
                          배송 시작 확인
                        </button>
                      )}
                      {selectedSafeTransaction.settlementStatus === '정산준비' && (
                        <button 
                          className="w-full bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                          onClick={() => {
                            setShowDetailModal(false);
                            handleProcessSettlement(selectedSafeTransaction.id);
                          }}
                        >
                          정산 처리 완료
                        </button>
                      )}
                      <button 
                        className="w-full bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                        onClick={() => handleUpdateNotes(selectedSafeTransaction.id, selectedSafeTransaction.adminNotes || '')}
                      >
                        메모 수정
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              {/* Modal Footer */}
              <div className="mt-6 flex justify-end">
                <button
                  onClick={() => setShowDetailModal(false)}
                  className="bg-gray-300 hover:bg-gray-400 text-gray-800 px-4 py-2 rounded-md text-sm font-medium"
                >
                  닫기
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
