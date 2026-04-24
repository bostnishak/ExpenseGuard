-- ============================================================
-- EXPENSEGUARD PRO — PHASE 1 MIGRATIONS
-- ============================================================

-- 1. Kullanıcılar tablosuna e-posta doğrulama kolonlarının eklenmesi
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS verification_token VARCHAR(255),
ADD COLUMN IF NOT EXISTS verification_expires_at TIMESTAMPTZ;

-- 2. Halihazırda var olan kullanıcıların (demo) doğrulanmış sayılması
UPDATE users SET is_email_verified = TRUE;

-- 3. Stripe için tenant tablosuna opsiyonel yeni alanlar (zaten var ama emin olmak için)
ALTER TABLE tenants 
ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS subscription_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(50) NOT NULL DEFAULT 'trialing',
ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ;
