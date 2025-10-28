/**
 * Theme Configuration
 * Matches Flutter app design system from lib/theme/app_theme.dart
 */

export const colors = {
  // Primary Colors
  primary: '#E6C757',        // Warm Yellow
  primaryDark: '#D4B545',
  primaryLight: '#F0D67A',

  // Secondary Colors
  secondary: '#5FAAAA',      // Teal
  secondaryDark: '#4D9898',
  secondaryLight: '#7BC4C4',

  // Accent Colors
  accent: '#D68A4C',         // Orange
  accentDark: '#C47840',
  accentLight: '#E0A16D',

  // Gradient Colors (for logo-based design)
  gradientStart: '#E6C757',
  gradientEnd: '#5FAAAA',

  // Semantic Colors
  success: '#4CAF50',
  warning: '#FF9800',
  error: '#F44336',
  info: '#2196F3',

  // Neutral Colors
  background: '#FFFFFF',
  surface: '#F5F5F5',
  surfaceVariant: '#E0E0E0',

  // Text Colors
  textPrimary: '#212121',
  textSecondary: '#757575',
  textDisabled: '#BDBDBD',
  textOnPrimary: '#212121',
  textOnSecondary: '#FFFFFF',

  // Border Colors
  border: '#E0E0E0',
  borderDark: '#BDBDBD',
  divider: '#E0E0E0',
} as const;

export const spacing = {
  xs: '0.25rem',    // 4px
  sm: '0.5rem',     // 8px
  md: '1rem',       // 16px
  lg: '1.5rem',     // 24px
  xl: '2rem',       // 32px
  xxl: '3rem',      // 48px
  xxxl: '4rem',     // 64px
} as const;

export const borderRadius = {
  sm: '0.25rem',    // 4px
  md: '0.5rem',     // 8px
  lg: '0.75rem',    // 12px
  xl: '1rem',       // 16px
  xxl: '1.5rem',    // 24px
  full: '9999px',   // Fully rounded
} as const;

export const shadows = {
  none: 'none',
  sm: '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
  md: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
  lg: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
  xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
  xxl: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
} as const;

export const typography = {
  fontFamily: {
    sans: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    mono: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace',
  },
  fontSize: {
    xs: '0.75rem',      // 12px
    sm: '0.875rem',     // 14px
    base: '1rem',       // 16px
    lg: '1.125rem',     // 18px
    xl: '1.25rem',      // 20px
    '2xl': '1.5rem',    // 24px
    '3xl': '1.875rem',  // 30px
    '4xl': '2.25rem',   // 36px
    '5xl': '3rem',      // 48px
  },
  fontWeight: {
    normal: '400',
    medium: '500',
    semibold: '600',
    bold: '700',
  },
  lineHeight: {
    tight: '1.25',
    normal: '1.5',
    relaxed: '1.75',
  },
} as const;

export const breakpoints = {
  sm: '640px',
  md: '768px',
  lg: '1024px',
  xl: '1280px',
  '2xl': '1536px',
} as const;

export const zIndex = {
  dropdown: 1000,
  sticky: 1020,
  fixed: 1030,
  modalBackdrop: 1040,
  modal: 1050,
  popover: 1060,
  tooltip: 1070,
} as const;

/**
 * Gradient utility
 */
export const gradients = {
  primary: `linear-gradient(135deg, ${colors.gradientStart} 0%, ${colors.gradientEnd} 100%)`,
  primaryVertical: `linear-gradient(180deg, ${colors.gradientStart} 0%, ${colors.gradientEnd} 100%)`,
  primaryHorizontal: `linear-gradient(90deg, ${colors.gradientStart} 0%, ${colors.gradientEnd} 100%)`,
} as const;

/**
 * Animation durations
 */
export const transitions = {
  fast: '150ms',
  base: '200ms',
  slow: '300ms',
  slower: '500ms',
} as const;

/**
 * Common component styles
 */
export const commonStyles = {
  container: 'container mx-auto px-4',
  card: 'bg-white rounded-lg shadow-md',
  button: {
    base: 'px-4 py-2 rounded-lg font-medium transition-colors duration-200',
    primary: 'bg-primary text-textOnPrimary hover:bg-primaryDark',
    secondary: 'bg-secondary text-textOnSecondary hover:bg-secondaryDark',
    outline: 'border-2 border-primary text-primary hover:bg-primary hover:text-textOnPrimary',
  },
  input: 'w-full px-4 py-2 border border-border rounded-lg focus:outline-none focus:border-primary transition-colors duration-200',
} as const;

export const theme = {
  colors,
  spacing,
  borderRadius,
  shadows,
  typography,
  breakpoints,
  zIndex,
  gradients,
  transitions,
  commonStyles,
};

export default theme;