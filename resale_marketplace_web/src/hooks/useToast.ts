'use client';

import { useState, useCallback } from 'react';
import { ToastType } from '@/components/Toast';

interface ToastState {
  message: string;
  type: ToastType;
  id: number;
}

const MAX_TOASTS = 5; // Maximum number of toasts to display

export function useToast() {
  const [toasts, setToasts] = useState<ToastState[]>([]);

  const showToast = useCallback((message: string, type: ToastType = 'info') => {
    const id = Date.now() + Math.random(); // Ensure unique IDs
    setToasts((prev) => {
      const newToasts = [...prev, { message, type, id }];
      // Keep only the latest MAX_TOASTS toasts
      return newToasts.slice(-MAX_TOASTS);
    });
  }, []);

  const hideToast = useCallback((id: number) => {
    setToasts((prev) => prev.filter((toast) => toast.id !== id));
  }, []);

  const success = useCallback((message: string) => showToast(message, 'success'), [showToast]);
  const error = useCallback((message: string) => showToast(message, 'error'), [showToast]);
  const warning = useCallback((message: string) => showToast(message, 'warning'), [showToast]);
  const info = useCallback((message: string) => showToast(message, 'info'), [showToast]);

  return {
    toasts,
    showToast,
    hideToast,
    success,
    error,
    warning,
    info,
  };
}
