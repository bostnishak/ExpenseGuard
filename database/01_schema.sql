-- ============================================================
-- EXPENSEGUARD PRO — DATABASE SCHEMA (PostgreSQL)
-- 3NF Normalize, Multi-Tenant, Encrypted Sensitive Columns
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- TABLE: tenants (Her şirket = 1 tenant)
-- ============================================================
CREATE TABLE tenants (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(200) NOT NULL,
    domain        VARCHAR(100) UNIQUE NOT NULL,  -- e.g. "acme.com"
    plan          VARCHAR(50)  NOT NULL DEFAULT 'starter',  -- starter|enterprise|corporate
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    
    -- Stripe Billing
    stripe_customer_id  VARCHAR(100),
    subscription_id     VARCHAR(100),
    subscription_status VARCHAR(50) NOT NULL DEFAULT 'trialing',
    trial_ends_at       TIMESTAMPTZ,

    -- White-Label (Faz 2)
    theme_color         VARCHAR(20),
    logo_url            TEXT,
    custom_domain       VARCHAR(100),

    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: departments
-- ============================================================
CREATE TABLE departments (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name          VARCHAR(150) NOT NULL,
    code          VARCHAR(20)  NOT NULL,          -- e.g. "IT", "HR", "FIN"
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, code)                      -- Candidate Key: (tenant_id, code)
);

-- ============================================================
-- TABLE: users (Çalışanlar, Yöneticiler, Adminler)
-- Role: employee | manager | finance | admin
-- ============================================================
CREATE TABLE users (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    department_id   UUID         REFERENCES departments(id) ON DELETE SET NULL,
    email           VARCHAR(254) NOT NULL,
    password_hash   TEXT         NOT NULL,   -- bcrypt hash, never plaintext
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    role            VARCHAR(20)  NOT NULL DEFAULT 'employee'
                    CHECK (role IN ('employee','manager','finance','admin')),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, email)               -- Candidate Key: (tenant_id, email)
);

-- ============================================================
-- TABLE: budget_limits (Departman bazlı aylık bütçe)
-- ============================================================
CREATE TABLE budget_limits (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    department_id   UUID         NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
    period_year     SMALLINT     NOT NULL,
    period_month    SMALLINT     NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    limit_amount    NUMERIC(15,2) NOT NULL CHECK (limit_amount >= 0),
    currency        CHAR(3)      NOT NULL DEFAULT 'TRY',
    created_by      UUID         REFERENCES users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (department_id, period_year, period_month)  -- Candidate Key
);

-- ============================================================
-- TABLE: expense_receipts (Ana fiş tablosu)
-- Hassas kolonlar: amount, tax_amount → pgcrypto ile şifreli
-- ============================================================
CREATE TABLE expense_receipts (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    department_id       UUID         NOT NULL REFERENCES departments(id),
    submitted_by        UUID         NOT NULL REFERENCES users(id),
    approved_by         UUID         REFERENCES users(id),

    -- Fiş Bilgileri (OCR tarafından doldurulur)
    receipt_date        DATE         NOT NULL,
    vendor_name         VARCHAR(200),
    category            VARCHAR(50)  NOT NULL DEFAULT 'other',
                        -- food|transport|accommodation|fuel|office|entertainment|other

    -- Finansal Veriler — Şifreli olarak saklanır (pgp_sym_encrypt)
    -- Uygulama katmanında decrypt edilir, key: app environment variable
    amount_encrypted    BYTEA        NOT NULL,   -- Gerçek tutar (şifreli)
    tax_amount_encrypted BYTEA,                  -- KDV tutarı (şifreli)
    currency            CHAR(3)      NOT NULL DEFAULT 'TRY',

    -- Düz metin alanlar (hızlı sorgu için)
    amount_display      NUMERIC(15,2) NOT NULL,  -- Yalnızca görüntüleme, doğrulama için encrypted kullan
    tax_rate            NUMERIC(5,2),            -- KDV oranı (%)

    -- Faz 3: Multi-Currency & ERP
    exchange_rate       NUMERIC(15,6),           -- Kur (TCMB)
    amount_try          NUMERIC(15,2) NOT NULL DEFAULT 0, -- TL karşılığı
    is_erp_synced       BOOLEAN       NOT NULL DEFAULT FALSE,

    -- Dosya / OCR
    image_path          TEXT,                    -- Object storage path (S3/Azure Blob)
    ocr_raw_text        TEXT,                    -- OCR'dan ham metin

    -- Fraud / AI Analiz
    fraud_score         SMALLINT     CHECK (fraud_score BETWEEN 0 AND 100),
    fraud_reasons       JSONB,                   -- AI'dan gelen gerekçeler dizisi
    risk_level          VARCHAR(10)  DEFAULT 'pending'
                        CHECK (risk_level IN ('pending','low','medium','high')),

    -- Durum Yönetimi
    status              VARCHAR(20)  NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','ai_processing','approved','rejected','flagged')),
    rejection_reason    TEXT,

    -- Metadata
    submitted_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    processed_at        TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: notifications (Faz 3: Mobil Bildirimler)
-- ============================================================
CREATE TABLE notifications (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id     UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    title         VARCHAR(200) NOT NULL,
    message       TEXT         NOT NULL,
    is_read       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: user_device_tokens (Faz 3: FCM / Push Notifications)
-- ============================================================
CREATE TABLE user_device_tokens (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_token  VARCHAR(255) NOT NULL,
    device_type   VARCHAR(20)  NOT NULL DEFAULT 'ios',
    last_used_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

-- ============================================================
-- TABLE: audit_log (DEĞİŞMEZ denetim izi — trigger tarafından doldurulur)
-- Bu tabloya uygulama katmanından YAZMA YETKİSİ YOKTUR
-- Sadece audit_trigger_user rolü yazabilir
-- ============================================================
CREATE TABLE audit_log (
    id              BIGSERIAL    PRIMARY KEY,
    tenant_id       UUID         NOT NULL,
    table_name      VARCHAR(100) NOT NULL,
    record_id       UUID         NOT NULL,
    operation       CHAR(6)      NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    changed_by      UUID,        -- users.id (NULL ise sistem işlemi)
    changed_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    old_values      JSONB,       -- DELETE/UPDATE: önceki değerler
    new_values      JSONB,       -- INSERT/UPDATE: sonraki değerler
    ip_address      INET,
    user_agent      TEXT
);

-- Audit log'a sadece okuma ve trigger yazması izin ver
-- (Gerçek deploy'da ayrı DB user ile sağlanır)
COMMENT ON TABLE audit_log IS 'Immutable audit trail. Only writable via SQL triggers.';
