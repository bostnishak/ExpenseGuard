-- ============================================================
-- EXPENSEGUARD PRO — SQL TRIGGERS (Audit Trail)
-- Her UPDATE/DELETE işlemi audit_log'a otomatik yazılır
-- ============================================================

-- ============================================================
-- FUNCTION: generic_audit_trigger_fn
-- Her tabloda yeniden kullanılabilir generic trigger fonksiyonu
-- ============================================================
CREATE OR REPLACE FUNCTION generic_audit_trigger_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER  -- trigger'ın sahibi rolü ile çalışır, audit_log'a yazabilir
AS $$
DECLARE
    v_tenant_id   UUID;
    v_record_id   UUID;
    v_old_values  JSONB := NULL;
    v_new_values  JSONB := NULL;
    v_changed_by  UUID  := NULL;
    v_ip_address  INET  := NULL;
BEGIN
    -- tenant_id ve id sütunlarını dinamik olarak al
    IF TG_OP = 'DELETE' THEN
        v_tenant_id  := OLD.tenant_id;
        v_record_id  := OLD.id;
        v_old_values := to_jsonb(OLD);
    ELSIF TG_OP = 'INSERT' THEN
        v_tenant_id  := NEW.tenant_id;
        v_record_id  := NEW.id;
        v_new_values := to_jsonb(NEW);
    ELSE  -- UPDATE
        v_tenant_id  := NEW.tenant_id;
        v_record_id  := NEW.id;
        v_old_values := to_jsonb(OLD);
        v_new_values := to_jsonb(NEW);
    END IF;

    -- 🔒 GÜVENLİK: İşlemi yapan kullanıcıyı session variable'dan al
    -- Uygulama katmanı: SET LOCAL app.current_user_id = '<user_uuid>';
    BEGIN
        v_changed_by := current_setting('app.current_user_id', true)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_changed_by := NULL;  -- Session variable yoksa NULL bırak
    END;

    -- IP adresini session variable'dan al
    -- Uygulama katmanı: SET LOCAL app.client_ip = '<ip>';
    BEGIN
        v_ip_address := current_setting('app.client_ip', true)::INET;
    EXCEPTION WHEN OTHERS THEN
        v_ip_address := NULL;
    END;

    -- Audit log'a yaz (bu satır asla başarısız olmaz, transaction ile birlikte)
    INSERT INTO audit_log (
        tenant_id,
        table_name,
        record_id,
        operation,
        changed_by,
        changed_at,
        ip_address,
        old_values,
        new_values
    ) VALUES (
        v_tenant_id,
        TG_TABLE_NAME,
        v_record_id,
        TG_OP::CHAR(6),
        v_changed_by,
        NOW(),
        v_ip_address,
        v_old_values,
        v_new_values
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- ============================================================
-- TRIGGER: expense_receipts — Her değişiklik kayıt altında
-- ============================================================
CREATE TRIGGER trg_receipts_audit
    AFTER INSERT OR UPDATE OR DELETE
    ON expense_receipts
    FOR EACH ROW
    EXECUTE FUNCTION generic_audit_trigger_fn();

-- ============================================================
-- TRIGGER: users — Kullanıcı değişiklikleri izlenir
-- ============================================================
CREATE TRIGGER trg_users_audit
    AFTER INSERT OR UPDATE OR DELETE
    ON users
    FOR EACH ROW
    EXECUTE FUNCTION generic_audit_trigger_fn();

-- ============================================================
-- TRIGGER: budget_limits — Bütçe değişiklikleri izlenir
-- ============================================================
CREATE TRIGGER trg_budget_audit
    AFTER INSERT OR UPDATE OR DELETE
    ON budget_limits
    FOR EACH ROW
    EXECUTE FUNCTION generic_audit_trigger_fn();

-- ============================================================
-- FUNCTION: update_updated_at_column
-- updated_at sütununu otomatik güncelle
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- updated_at trigger'larını ilgili tablolara ekle
CREATE TRIGGER trg_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_receipts_updated_at
    BEFORE UPDATE ON expense_receipts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- FUNCTION: check_budget_limit
-- Yeni fiş eklendiğinde bütçe aşımı kontrolü yapar
-- Aşım varsa receipt'i FLAGGED olarak işaretler
-- ============================================================
CREATE OR REPLACE FUNCTION check_budget_limit_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_limit        NUMERIC(15,2);
    v_spent        NUMERIC(15,2);
BEGIN
    -- Bu ay bu departmanın bütçe limitini al
    SELECT limit_amount INTO v_limit
    FROM budget_limits
    WHERE department_id = NEW.department_id
      AND period_year   = EXTRACT(YEAR FROM NEW.receipt_date)::SMALLINT
      AND period_month  = EXTRACT(MONTH FROM NEW.receipt_date)::SMALLINT
    LIMIT 1;

    IF v_limit IS NULL THEN
        RETURN NEW;  -- Limit tanımlı değilse geç
    END IF;

    -- Bu ay toplam harcamayı hesapla
    SELECT COALESCE(SUM(amount_display), 0) INTO v_spent
    FROM expense_receipts
    WHERE department_id = NEW.department_id
      AND status NOT IN ('rejected')
      AND EXTRACT(YEAR  FROM receipt_date) = EXTRACT(YEAR  FROM NEW.receipt_date)
      AND EXTRACT(MONTH FROM receipt_date) = EXTRACT(MONTH FROM NEW.receipt_date);

    -- Yeni fiş ile birlikte limiti aştı mı?
    IF (v_spent + NEW.amount_display) > v_limit THEN
        -- Durumu flagged yap, manager incelemesine gönder
        NEW.status     := 'flagged';
        NEW.fraud_reasons := COALESCE(NEW.fraud_reasons, '[]'::jsonb) ||
            jsonb_build_array(jsonb_build_object(
                'rule', 'BUDGET_EXCEEDED',
                'message', format('Departman bütçesi aşıldı. Limit: %s, Harcanan: %s, Yeni: %s',
                    v_limit, v_spent, NEW.amount_display)
            ));
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_budget_check
    BEFORE INSERT ON expense_receipts
    FOR EACH ROW
    EXECUTE FUNCTION check_budget_limit_fn();
