-- ============================================================
-- PolyChat Anonymous Analytics — Supabase Setup Script
-- Run this in your Supabase project's SQL Editor (Database > SQL Editor)
-- ============================================================

-- 1. Devices table
CREATE TABLE devices (
  device_id UUID PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  app_version TEXT CHECK (app_version IS NULL OR length(app_version) <= 20),
  os_version TEXT CHECK (os_version IS NULL OR length(os_version) <= 20)
);

-- 2. Error events (append-only log)
CREATE TABLE error_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(device_id),
  error_type TEXT NOT NULL CHECK (length(error_type) <= 200),
  error_domain TEXT NOT NULL CHECK (length(error_domain) <= 100),
  occurred_at TIMESTAMPTZ NOT NULL,
  conversation_id UUID,
  model_name TEXT CHECK (model_name IS NULL OR length(model_name) <= 100),
  provider_name TEXT CHECK (provider_name IS NULL OR length(provider_name) <= 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_error_device ON error_events(device_id);

-- 3. Message events (one row per message — single source of truth)
CREATE TABLE message_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(device_id),
  conversation_id UUID NOT NULL,
  model_name TEXT NOT NULL CHECK (length(model_name) <= 100),
  provider_name TEXT NOT NULL CHECK (length(provider_name) <= 100),
  message_role TEXT NOT NULL CHECK (message_role IN ('user', 'assistant', 'tool')),
  tool_name TEXT CHECK (tool_name IS NULL OR length(tool_name) <= 100),
  attachment_type TEXT CHECK (attachment_type IS NULL OR length(attachment_type) <= 50),
  timestamp TIMESTAMPTZ NOT NULL CHECK (timestamp <= now() + interval '1 day'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_message_device ON message_events(device_id);
CREATE INDEX idx_message_conversation ON message_events(conversation_id);
CREATE INDEX idx_message_timestamp ON message_events(timestamp);
CREATE INDEX idx_message_tool ON message_events(tool_name) WHERE tool_name IS NOT NULL;

-- 4. Session events (VIEW derived from message_events — not a table)
CREATE VIEW session_events AS
SELECT
  device_id,
  conversation_id,
  model_name,
  provider_name,
  MIN(timestamp) AS started_at,
  MAX(timestamp) AS ended_at,
  COUNT(*) AS message_count
FROM message_events
GROUP BY device_id, conversation_id, model_name, provider_name;

-- 5. Pre-aggregated daily stats (dashboard reads from this)
CREATE TABLE daily_stats (
  stat_date DATE NOT NULL,
  model_name TEXT NOT NULL,
  provider_name TEXT NOT NULL,
  total_sessions INT NOT NULL DEFAULT 0,
  total_messages INT NOT NULL DEFAULT 0,
  total_errors INT NOT NULL DEFAULT 0,
  unique_devices INT NOT NULL DEFAULT 0,
  PRIMARY KEY (stat_date, model_name, provider_name)
);
CREATE INDEX idx_daily_stats_date ON daily_stats(stat_date);

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;
-- Note: session_events is a VIEW — inherits RLS from message_events

-- INSERT: any client can insert (they only write their own device_id)
-- SELECT: open for all (data is fully anonymous, needed for community dashboard)
CREATE POLICY "insert_any" ON devices FOR INSERT WITH CHECK (true);
CREATE POLICY "select_all" ON devices FOR SELECT USING (true);

CREATE POLICY "insert_any" ON error_events FOR INSERT WITH CHECK (true);
CREATE POLICY "select_all" ON error_events FOR SELECT USING (true);

CREATE POLICY "insert_any" ON message_events FOR INSERT WITH CHECK (true);
CREATE POLICY "select_all" ON message_events FOR SELECT USING (true);

-- daily_stats: read-only for clients, written by trigger function
CREATE POLICY "select_all" ON daily_stats FOR SELECT USING (true);

-- ============================================================
-- Table-level GRANTs for the anon role (required by PostgREST)
-- ============================================================

GRANT SELECT, INSERT ON devices TO anon;
GRANT SELECT, INSERT ON error_events TO anon;
GRANT SELECT, INSERT ON message_events TO anon;
GRANT SELECT ON session_events TO anon;
GRANT SELECT ON daily_stats TO anon;

-- Reload PostgREST schema cache so grants take effect immediately
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- Trigger: refresh daily_stats on message_events insert
-- ============================================================

CREATE OR REPLACE FUNCTION refresh_daily_stats()
RETURNS TRIGGER AS $$
DECLARE
  v_date DATE := DATE(NEW.timestamp);
  v_sessions INT;
  v_messages INT;
  v_devices INT;
BEGIN
  -- Query message_events directly (not the VIEW) for performance at scale
  SELECT
    COUNT(DISTINCT conversation_id),
    COUNT(*),
    COUNT(DISTINCT device_id)
  INTO v_sessions, v_messages, v_devices
  FROM message_events
  WHERE DATE(timestamp) = v_date
    AND model_name = NEW.model_name
    AND provider_name = NEW.provider_name;

  INSERT INTO daily_stats (stat_date, model_name, provider_name, total_sessions, total_messages, total_errors, unique_devices)
  VALUES (v_date, NEW.model_name, NEW.provider_name, v_sessions, v_messages, 0, v_devices)
  ON CONFLICT (stat_date, model_name, provider_name)
  DO UPDATE SET
    total_sessions = v_sessions,
    total_messages = v_messages,
    unique_devices = v_devices;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_refresh_daily_stats
  AFTER INSERT ON message_events
  FOR EACH ROW EXECUTE FUNCTION refresh_daily_stats();

-- ============================================================
-- Trigger: update daily_stats error counts on error_events insert
-- ============================================================

CREATE OR REPLACE FUNCTION refresh_daily_error_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if model_name and provider_name are present
  IF NEW.model_name IS NOT NULL AND NEW.provider_name IS NOT NULL THEN
    INSERT INTO daily_stats (stat_date, model_name, provider_name, total_sessions, total_messages, total_errors, unique_devices)
    VALUES (DATE(NEW.occurred_at), NEW.model_name, NEW.provider_name, 0, 0, 1, 0)
    ON CONFLICT (stat_date, model_name, provider_name)
    DO UPDATE SET total_errors = daily_stats.total_errors + 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_refresh_daily_error_stats
  AFTER INSERT ON error_events
  FOR EACH ROW EXECUTE FUNCTION refresh_daily_error_stats();
