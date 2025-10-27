/**
 * Centralized currency formatting utilities
 */

export type Currency = 'KRW' | 'USD' | 'EUR' | 'JPY' | 'CNY';
export type Locale = 'ko-KR' | 'en-US' | 'ja-JP' | 'zh-CN';

interface FormatCurrencyOptions {
  currency?: Currency;
  locale?: Locale;
  minimumFractionDigits?: number;
  maximumFractionDigits?: number;
  useGrouping?: boolean;
}

/**
 * Format number as currency with locale support
 * @param amount - The amount to format
 * @param options - Formatting options
 * @returns Formatted currency string
 *
 * @example
 * formatCurrency(10000) // "₩10,000"
 * formatCurrency(10000, { currency: 'USD', locale: 'en-US' }) // "$10,000.00"
 */
export function formatCurrency(
  amount: number,
  options: FormatCurrencyOptions = {}
): string {
  const {
    currency = 'KRW',
    locale = 'ko-KR',
    minimumFractionDigits,
    maximumFractionDigits,
    useGrouping = true,
  } = options;

  // KRW doesn't use decimal places
  const fractionDigits = currency === 'KRW' ? 0 : minimumFractionDigits ?? 2;

  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: maximumFractionDigits ?? fractionDigits,
    useGrouping,
  }).format(amount);
}

/**
 * Format as Korean Won (default)
 * @param amount - The amount to format
 * @returns Formatted KRW string
 *
 * @example
 * formatKRW(10000) // "₩10,000"
 */
export function formatKRW(amount: number): string {
  return formatCurrency(amount, { currency: 'KRW', locale: 'ko-KR' });
}

/**
 * Format number without currency symbol
 * @param amount - The amount to format
 * @param locale - Locale for formatting
 * @returns Formatted number string
 *
 * @example
 * formatNumber(10000) // "10,000"
 * formatNumber(10000.5, 'en-US') // "10,000.5"
 */
export function formatNumber(amount: number, locale: Locale = 'ko-KR'): string {
  return new Intl.NumberFormat(locale).format(amount);
}

/**
 * Parse currency string to number
 * @param currencyString - Currency string to parse
 * @returns Parsed number or null if invalid
 *
 * @example
 * parseCurrency("₩10,000") // 10000
 * parseCurrency("$1,234.56") // 1234.56
 */
export function parseCurrency(currencyString: string): number | null {
  // Remove currency symbols and spaces
  const cleaned = currencyString.replace(/[₩$€¥,\s]/g, '');
  const parsed = parseFloat(cleaned);

  return isNaN(parsed) ? null : parsed;
}

/**
 * Calculate percentage of amount
 * @param amount - Base amount
 * @param percentage - Percentage to calculate
 * @returns Calculated amount
 *
 * @example
 * calculatePercentage(10000, 10) // 1000
 * calculatePercentage(10000, 15) // 1500
 */
export function calculatePercentage(amount: number, percentage: number): number {
  return (amount * percentage) / 100;
}

/**
 * Calculate commission amount
 * @param price - Product price
 * @param commissionRate - Commission rate percentage
 * @returns Commission amount
 *
 * @example
 * calculateCommission(10000, 10) // 1000
 * calculateCommission(10000, 15) // 1500
 */
export function calculateCommission(price: number, commissionRate: number): number {
  return calculatePercentage(price, commissionRate);
}

/**
 * Format price with commission info
 * @param price - Base price
 * @param commissionRate - Commission rate percentage
 * @returns Object with formatted strings
 *
 * @example
 * formatPriceWithCommission(10000, 10)
 * // { price: "₩10,000", commission: "₩1,000", total: "₩11,000" }
 */
export function formatPriceWithCommission(
  price: number,
  commissionRate: number
): {
  price: string;
  commission: string;
  total: string;
  commissionAmount: number;
} {
  const commissionAmount = calculateCommission(price, commissionRate);
  const total = price + commissionAmount;

  return {
    price: formatKRW(price),
    commission: formatKRW(commissionAmount),
    total: formatKRW(total),
    commissionAmount,
  };
}
