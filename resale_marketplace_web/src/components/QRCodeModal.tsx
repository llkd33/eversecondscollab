'use client';

import React, { useEffect, useState } from 'react';
import QRCode from 'qrcode';

interface QRCodeModalProps {
  isOpen: boolean;
  onClose: () => void;
  productId?: string;
}

export default function QRCodeModal({ isOpen, onClose, productId }: QRCodeModalProps) {
  const [qrCodeDataUrl, setQrCodeDataUrl] = useState<string>('');

  // QR 코드에 표시할 URL 생성 (임시로 everseconds.com 사용)
  const qrUrl = productId 
    ? `https://everseconds.com/product/${productId}`
    : 'https://everseconds.com';

  useEffect(() => {
    if (isOpen && qrUrl) {
      QRCode.toDataURL(qrUrl, {
        width: 192,
        margin: 2,
        color: {
          dark: '#000000',
          light: '#FFFFFF',
        },
      })
        .then((url) => {
          setQrCodeDataUrl(url);
        })
        .catch((err) => {
          console.error('QR 코드 생성 오류:', err);
        });
    }
  }, [isOpen, qrUrl]);

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
            앱에서 거래하기
          </h2>
          
          <p className="text-gray-600 mb-6">
            안전한 거래를 위해 앱을 다운로드하세요
          </p>
          
          {/* QR Code */}
          <div className="bg-gray-100 rounded-lg p-8 mb-6">
            <div className="bg-white rounded-lg p-4 flex items-center justify-center">
              {qrCodeDataUrl ? (
                <img 
                  src={qrCodeDataUrl} 
                  alt="QR Code" 
                  className="w-48 h-48"
                />
              ) : (
                <div className="w-48 h-48 flex items-center justify-center">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                </div>
              )}
            </div>
            <p className="text-sm text-gray-500 mt-4">
              휴대폰 카메라로 QR코드를 스캔하세요
            </p>
          </div>
          
          {/* App Store Buttons */}
          <div className="flex gap-4 justify-center mb-4">
            <button className="flex items-center gap-2 bg-black text-white px-4 py-2 rounded-lg hover:bg-gray-800 transition-colors">
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
              </svg>
              App Store
            </button>
            <button className="flex items-center gap-2 bg-gray-900 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/>
              </svg>
              Google Play
            </button>
          </div>
          
          {/* Features */}
          <div className="border-t pt-4">
            <div className="grid grid-cols-3 gap-2 text-center">
              <div>
                <div className="text-green-600 font-semibold text-sm">안전거래</div>
                <div className="text-xs text-gray-500">에스크로 시스템</div>
              </div>
              <div>
                <div className="text-blue-600 font-semibold text-sm">실시간 채팅</div>
                <div className="text-xs text-gray-500">1:1 메시징</div>
              </div>
              <div>
                <div className="text-orange-600 font-semibold text-sm">대신팔기</div>
                <div className="text-xs text-gray-500">수수료 혜택</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}