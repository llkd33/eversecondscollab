/**
 * Environment variable validation and type-safe access
 */

import { ValidationError } from './errorHandler';

interface EnvConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
  nodeEnv: 'development' | 'production' | 'test';
}

/**
 * Validate required environment variables
 */
function validateEnv(): EnvConfig {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const nodeEnv = process.env.NODE_ENV || 'development';

  const errors: string[] = [];

  if (!supabaseUrl) {
    errors.push('NEXT_PUBLIC_SUPABASE_URL is not defined');
  } else if (!supabaseUrl.startsWith('http')) {
    errors.push('NEXT_PUBLIC_SUPABASE_URL must be a valid URL starting with http(s)');
  }

  if (!supabaseAnonKey) {
    errors.push('NEXT_PUBLIC_SUPABASE_ANON_KEY is not defined');
  } else if (supabaseAnonKey.length < 20) {
    errors.push('NEXT_PUBLIC_SUPABASE_ANON_KEY appears to be invalid (too short)');
  }

  if (errors.length > 0) {
    const errorMessage = [
      'Environment validation failed:',
      ...errors.map(e => `  - ${e}`),
      '',
      'Please check your .env.local file and ensure all required variables are set.',
    ].join('\n');

    throw new ValidationError(errorMessage);
  }

  return {
    supabaseUrl: supabaseUrl!,
    supabaseAnonKey: supabaseAnonKey!,
    nodeEnv: nodeEnv as EnvConfig['nodeEnv'],
  };
}

// Validate on module load
let env: EnvConfig;

try {
  env = validateEnv();
} catch (error) {
  console.error('❌ Environment validation failed:', error);

  // Always throw error to prevent running with invalid configuration
  // This ensures the build fails early if env vars are not set
  throw error;
}

export const ENV = env;

/**
 * Type-safe environment variable access
 */
export function getEnv<K extends keyof EnvConfig>(key: K): EnvConfig[K] {
  return ENV[key];
}

/**
 * Check if running in production
 */
export function isProduction(): boolean {
  return ENV.nodeEnv === 'production';
}

/**
 * Check if running in development
 */
export function isDevelopment(): boolean {
  return ENV.nodeEnv === 'development';
}
