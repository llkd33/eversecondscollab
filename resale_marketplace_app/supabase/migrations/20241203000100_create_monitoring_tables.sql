-- Monitoring and observability supporting tables for admin dashboard
-- Created: 2024-12-03

CREATE TABLE IF NOT EXISTS public.system_events (
  id text PRIMARY KEY,
  type text NOT NULL,
  severity text NOT NULL,
  message text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_system_events_created_at
  ON public.system_events (created_at DESC);

CREATE TABLE IF NOT EXISTS public.security_alerts (
  id text PRIMARY KEY,
  type text NOT NULL,
  severity text NOT NULL,
  message text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_security_alerts_status_created
  ON public.security_alerts (status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.performance_metrics (
  id text PRIMARY KEY,
  metrics jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_performance_metrics_created
  ON public.performance_metrics (created_at DESC);

CREATE TABLE IF NOT EXISTS public.user_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  ip_address text,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_activity timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user
  ON public.user_sessions (user_id, last_activity DESC);

CREATE INDEX IF NOT EXISTS idx_user_sessions_ip
  ON public.user_sessions (ip_address);

CREATE TABLE IF NOT EXISTS public.auth_logs (
  id bigserial PRIMARY KEY,
  user_id uuid,
  ip_address text,
  success boolean NOT NULL DEFAULT false,
  context jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_logs_created_at
  ON public.auth_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_auth_logs_ip_success
  ON public.auth_logs (ip_address, success);

CREATE TABLE IF NOT EXISTS public.api_logs (
  id bigserial PRIMARY KEY,
  endpoint text,
  method text,
  status_code integer,
  duration_ms integer,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_api_logs_created_at
  ON public.api_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_api_logs_status_code
  ON public.api_logs (status_code);

ALTER TABLE public.system_events OWNER TO postgres;
ALTER TABLE public.security_alerts OWNER TO postgres;
ALTER TABLE public.performance_metrics OWNER TO postgres;
ALTER TABLE public.user_sessions OWNER TO postgres;
ALTER TABLE public.auth_logs OWNER TO postgres;
ALTER TABLE public.api_logs OWNER TO postgres;

