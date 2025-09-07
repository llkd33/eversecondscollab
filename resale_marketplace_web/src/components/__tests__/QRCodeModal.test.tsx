import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import QRCodeModal from '../QRCodeModal';

// Mock react-qr-code
jest.mock('react-qr-code', () => {
  return function MockQRCode({ value }: { value: string }) {
    return <div data-testid="qr-code" data-value={value}>QR Code</div>;
  };
});

describe('QRCodeModal', () => {
  const mockOnClose = jest.fn();

  beforeEach(() => {
    mockOnClose.mockClear();
  });

  it('renders when isOpen is true', () => {
    render(
      <QRCodeModal 
        isOpen={true} 
        onClose={mockOnClose} 
        productId="test-product-1" 
      />
    );

    expect(screen.getByText('에버세컨즈 앱에서 거래하기')).toBeInTheDocument();
    expect(screen.getByText('안전한 거래와 실시간 채팅을 위해')).toBeInTheDocument();
  });

  it('does not render when isOpen is false', () => {
    render(
      <QRCodeModal 
        isOpen={false} 
        onClose={mockOnClose} 
        productId="test-product-1" 
      />
    );

    expect(screen.queryByText('에버세컨즈 앱에서 거래하기')).not.toBeInTheDocument();
  });

  it('generates correct QR code value with productId', () => {
    render(
      <QRCodeModal 
        isOpen={true} 
        onClose={mockOnClose} 
        productId="test-product-1" 
      />
    );

    const qrCode = screen.getByTestId('qr-code');
    expect(qrCode).toHaveAttribute('data-value', 'everseconds://product/test-product-1');
  });

  it('generates default QR code value without productId', () => {
    render(
      <QRCodeModal 
        isOpen={true} 
        onClose={mockOnClose} 
      />
    );

    const qrCode = screen.getByTestId('qr-code');
    expect(qrCode).toHaveAttribute('data-value', 'everseconds://home');
  });

  it('calls onClose when close button is clicked', () => {
    render(
      <QRCodeModal 
        isOpen={true} 
        onClose={mockOnClose} 
        productId="test-product-1" 
      />
    );

    const closeButton = screen.getByRole('button');
    fireEvent.click(closeButton);

    expect(mockOnClose).toHaveBeenCalledTimes(1);
  });

  it('calls onClose when backdrop is clicked', () => {
    render(
      <QRCodeModal 
        isOpen={true} 
        onClose={mockOnClose} 
        productId="test-product-1" 
      />
    );

    const backdrop = document.querySelector('.absolute.inset-0');
    if (backdrop) {
      fireEvent.click(backdrop);
      expect(mockOnClose).toHaveBeenCalledTimes(1);
    }
  });

  it('displays app store links', () => {
    render(
      <QRCodeModal 
        isOpen={true} 
        onClose={mockOnClose} 
        productId="test-product-1" 
      />
    );

    expect(screen.getByText('App Store')).toBeInTheDocument();
    expect(screen.getByText('Google Play')).toBeInTheDocument();
  });

  it('displays feature highlights', () => {
    render(
      <QRCodeModal 
        isOpen={true} 
        onClose={mockOnClose} 
        productId="test-product-1" 
      />
    );

    expect(screen.getByText('안전거래')).toBeInTheDocument();
    expect(screen.getByText('실시간 채팅')).toBeInTheDocument();
    expect(screen.getByText('대신팔기')).toBeInTheDocument();
  });
});