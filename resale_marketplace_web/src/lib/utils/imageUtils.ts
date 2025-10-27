/**
 * Image utility functions for consistent image handling
 */

export const DEFAULT_PRODUCT_IMAGE = '/images/default-product.png';
export const DEFAULT_PROFILE_IMAGE = '/images/default-profile.png';

/**
 * Get product image URL with fallback
 */
export function getProductImageUrl(imageUrl?: string | string[] | null, index: number = 0): string {
  if (!imageUrl) {
    return DEFAULT_PRODUCT_IMAGE;
  }

  // Handle array of images
  if (Array.isArray(imageUrl)) {
    return imageUrl[index] || imageUrl[0] || DEFAULT_PRODUCT_IMAGE;
  }

  // Handle single image URL
  return imageUrl;
}

/**
 * Get profile image URL with fallback
 */
export function getProfileImageUrl(imageUrl?: string | null): string {
  return imageUrl || DEFAULT_PROFILE_IMAGE;
}

/**
 * Validate image URL
 * Works in both server and client environments
 */
export function isValidImageUrl(url: string): boolean {
  try {
    // Use a default base URL for SSR environments
    const baseUrl = typeof window !== 'undefined' ? window.location.origin : 'http://localhost';
    const urlObj = new URL(url, baseUrl);
    return urlObj.protocol === 'http:' || urlObj.protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Get optimized image URL for Next.js Image component
 */
export function getOptimizedImageUrl(
  url: string,
  options?: {
    width?: number;
    quality?: number;
  }
): string {
  const params = new URLSearchParams();

  if (options?.width) {
    params.append('w', options.width.toString());
  }

  if (options?.quality) {
    params.append('q', options.quality.toString());
  }

  const queryString = params.toString();
  return queryString ? `${url}?${queryString}` : url;
}

/**
 * Generate blur data URL for image placeholder
 * Works in both server and client environments
 */
export function getBlurDataUrl(color: string = '#f3f4f6'): string {
  const svg = `<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100" fill="${color}"/></svg>`;

  // Server-side: Use Node.js Buffer
  if (typeof window === 'undefined') {
    return `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
  }

  // Client-side: Use btoa
  return `data:image/svg+xml;base64,${btoa(svg)}`;
}
