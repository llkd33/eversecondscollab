import { createBrowserClient } from '@supabase/ssr'

// Supabase URL과 익명 키 설정
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables')
}

// 브라우저 클라이언트 생성 함수
export function createClient() {
  return createBrowserClient(supabaseUrl, supabaseAnonKey)
}

// 기본 클라이언트 인스턴스
export const supabase = createClient()