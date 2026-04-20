-- ============================================================
-- EXPENSEGUARD PRO — INDEXES & PERFORMANCE
-- ============================================================

-- Tenant-based isolation queries (tüm sorgularda tenant_id filtresi)
CREATE INDEX idx_users_tenant           ON users (tenant_id);
CREATE INDEX idx_departments_tenant     ON departments (tenant_id);
CREATE INDEX idx_receipts_tenant        ON expense_receipts (tenant_id);
CREATE INDEX idx_receipts_tenant_status ON expense_receipts (tenant_id, status);
CREATE INDEX idx_receipts_department    ON expense_receipts (department_id);
CREATE INDEX idx_receipts_submitted_by  ON expense_receipts (submitted_by);

-- Fraud detection queries
CREATE INDEX idx_receipts_fraud_score   ON expense_receipts (fraud_score DESC)
    WHERE fraud_score IS NOT NULL;
CREATE INDEX idx_receipts_risk_level    ON expense_receipts (risk_level)
    WHERE risk_level IN ('high', 'medium');

-- Date-based budget period queries
CREATE INDEX idx_receipts_date          ON expense_receipts (receipt_date);
CREATE INDEX idx_budget_period          ON budget_limits (department_id, period_year, period_month);

-- Audit log queries
CREATE INDEX idx_audit_tenant           ON audit_log (tenant_id);
CREATE INDEX idx_audit_record           ON audit_log (record_id);
CREATE INDEX idx_audit_table_op         ON audit_log (table_name, operation);
CREATE INDEX idx_audit_changed_at       ON audit_log (changed_at DESC);

-- ============================================================
-- EXPENSEGUARD PRO — SEED DATA (Demo / Development)
-- ============================================================

-- Demo Tenant: ExpenseGuard
INSERT INTO tenants (id, name, domain, plan) VALUES
    ('11111111-1111-1111-1111-111111111111', 'ExpenseGuard Pro Demo', 'expenseguard.com', 'enterprise');

-- Demo Departments
INSERT INTO departments (id, tenant_id, name, code) VALUES
    ('21111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Bilgi Teknolojileri', 'IT'),
    ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'İnsan Kaynakları',    'HR'),
    ('23333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Finans',               'FIN'),
    ('24444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Satış & Pazarlama',   'SAL');

-- Demo Users (password: "Test1234!" → bcrypt hash)
-- bcrypt hash of "Test1234!" : $2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2NJF.omaKa
INSERT INTO users (id, tenant_id, department_id, email, password_hash, first_name, last_name, role) VALUES
    -- Admin
    ('31111111-1111-1111-1111-111111111111',
     '11111111-1111-1111-1111-111111111111', NULL,
     'admin@expenseguard.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2NJF.omaKa',
     'Sistem', 'Admin', 'admin'),
    -- Finance
    ('32222222-2222-2222-2222-222222222222',
     '11111111-1111-1111-1111-111111111111',
     '23333333-3333-3333-3333-333333333333',
     'finans@expenseguard.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2NJF.omaKa',
     'Ayşe', 'Kaya', 'finance'),
    -- IT Manager
    ('33333333-3333-3333-3333-333333333333',
     '11111111-1111-1111-1111-111111111111',
     '21111111-1111-1111-1111-111111111111',
     'yonetici@expenseguard.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2NJF.omaKa',
     'Mehmet', 'Demir', 'manager'),
    -- Employee
    ('34444444-4444-4444-4444-444444444444',
     '11111111-1111-1111-1111-111111111111',
     '21111111-1111-1111-1111-111111111111',
     'calisan@expenseguard.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2NJF.omaKa',
     'Ali', 'Yılmaz', 'employee');

-- Budget Limits (2024 Ocak-Aralık)
INSERT INTO budget_limits (tenant_id, department_id, period_year, period_month, limit_amount) VALUES
    ('11111111-1111-1111-1111-111111111111', '21111111-1111-1111-1111-111111111111', 2024, 1, 50000.00),
    ('11111111-1111-1111-1111-111111111111', '21111111-1111-1111-1111-111111111111', 2024, 2, 50000.00),
    ('11111111-1111-1111-1111-111111111111', '21111111-1111-1111-1111-111111111111', 2024, 3, 50000.00),
    ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 2024, 1, 25000.00),
    ('11111111-1111-1111-1111-111111111111', '23333333-3333-3333-3333-333333333333', 2024, 1, 75000.00),
    ('11111111-1111-1111-1111-111111111111', '24444444-4444-4444-4444-444444444444', 2024, 1, 100000.00);
