// Type definitions for Deno edge functions

declare module 'https://deno.land/std@0.168.0/http/server.ts' {
  export function serve(handler: (req: Request) => Response | Promise<Response>): void;
}

declare module 'https://esm.sh/@supabase/supabase-js@2' {
  export * from '@supabase/supabase-js';
}

declare namespace Deno {
  export namespace env {
    export function get(key: string): string | undefined;
  }
}
