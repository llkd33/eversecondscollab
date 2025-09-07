'use client';

import React, { useMemo } from 'react';
import QRCode from 'react-qr-code';

interface QRCodeModalProps {
  isOpen: boolean;
  onClose: () => void;
  productId?: string;
}

export default function QRCodeModal({ isOpen, onClose, productId }: QRCodeModalProps) {
  const qrValue = useMemo(() => {
    // Prefer deep link for installed app; otherwise, a web fallback
    if (productId) {
      return `everseconds://product/${productId}`;
    }
    // Generic app deep link fallback
    return `everseconds://home`;
  }, [productId]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black bg-opacity-50"
        onClick={onClose}
      />
      
      {/* Modal Content */}
      <div className="relative bg-white rounded-2xl p-8 max-w-md w-full mx-4 shadow-2xl">
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-500 hover:text-gray-700 transition-colors"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
        
        <div className="text-center">
          {/* Icon */}
          <div className="mx-auto w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-4">
            <svg className="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} 
                d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
            </svg>
          </div>
          
          <h2 className="text-2xl font-bold text-gray-900 mb-2">
            에버세컨즈 앱에서 거래하기
          </h2>
          
          <p className="text-gray-600 mb-6">
            안전한 거래와 실시간 채팅을 위해<br />
            모바일 앱을 다운로드하세요
          </p>
          
          {/* QR Code */}
          <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-lg p-8 mb-6">
            <div className="bg-white rounded-lg p-6 flex items-center justify-center shadow-sm">
              <QRCode 
                value={qrValue} 
                size={192}
                bgColor="#ffffff"
                fgColor="#1f2937"
                level="M"
              />
            </div>
            <div className="text-center mt-4">
              <p className="text-sm text-gray-600 font-medium">
                📱 휴대폰 카메라로 QR코드를 스캔하세요
              </p>
              <p className="text-xs text-gray-500 mt-1">
                {productId ? '해당 상품 페이지로 바로 이동합니다' : '앱 홈화면으로 이동합니다'}
              </p>
            </div>
          </div>
          
          {/* App Store Buttons */}
          <div className="space-y-3 mb-6">
            <p className="text-sm text-gray-600 text-center font-medium">앱 다운로드</p>
            <div className="flex gap-3 justify-center">
              <a 
                href="https://apps.apple.com/" 
                target="_blank" 
                rel="noreferrer" 
                className="flex items-center gap-2 bg-black text-white px-4 py-3 rounded-lg hover:bg-gray-800 transition-colors shadow-sm"
              >
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                </svg>
                <span className="text-sm font-medium">App Store</span>
              </a>
              <a 
                href="https://play.google.com/store" 
                target="_blank" 
                rel="noreferrer" 
                className="flex items-center gap-2 bg-green-600 text-white px-4 py-3 rounded-lg hover:bg-green-700 transition-colors shadow-sm"
              >
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/>
                </svg>
                <span className="text-sm font-medium">Google Play</span>
              </a>
            </div>
          </div>
          
          {/* Features */}
          <div className="border-t pt-6">
            <p className="text-sm text-gray-600 text-center font-medium mb-4">앱에서만 가능한 기능</p>
            <div className="grid grid-cols-3 gap-4 text-center">
              <div className="p-3 bg-green-50 rounded-lg">
                <div className="w-8 h-8 mx-auto mb-2 bg-green-100 rounded-full flex items-center justify-center">
                  <svg className="w-4 h-4 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="text-green-700 font-semibold text-sm">안전거래</div>
                <div className="text-xs text-green-600 mt-1">에스크로 시스템</div>
              </div>
              <div className="p-3 bg-blue-50 rounded-lg">
                <div className="w-8 h-8 mx-auto mb-2 bg-blue-100 rounded-full flex items-center justify-center">
                  <svg className="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M18 10c0 3.866-3.582 7-8 7a8.841 8.841 0 01-4.083-.98L2 17l1.338-3.123C2.493 12.767 2 11.434 2 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9H5v2h2V9zm8 0h-2v2h2V9zM9 9h2v2H9V9z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="text-blue-700 font-semibold text-sm">실시간 채팅</div>
                <div className="text-xs text-blue-600 mt-1">1:1 메시징</div>
              </div>
              <div className="p-3 bg-orange-50 rounded-lg">
                <div className="w-8 h-8 mx-auto mb-2 bg-orange-100 rounded-full flex items-center justify-center">
                  <svg className="w-4 h-4 text-orange-600" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M8 5a1 1 0 100 2h5.586l-1.293 1.293a1 1 0 001.414 1.414l3-3a1 1 0 000-1.414l-3-3a1 1 0 10-1.414 1.414L13.586 5H8zM12 15a1 1 0 100-2H6.414l1.293-1.293a1 1 0 10-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L6.414 15H12z" />
                  </svg>
                </div>
                <div className="text-orange-700 font-semibold text-sm">대신팔기</div>
                <div className="text-xs text-orange-600 mt-1">수수료 혜택</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
