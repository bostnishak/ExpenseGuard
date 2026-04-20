/* ══════════════════════════════════════════════════════════════
   EXPENSEGUARD — LOGIN.JS  (v4 — Demo + API Hybrid)
   Demo modda API olmadan da çalışır, API varsa gerçek login yapar
══════════════════════════════════════════════════════════════ */
'use strict';

/* ── DEMO ACCOUNTS (Frontend Fallback) ──────────────────── */
const DEMO_ACCOUNTS = {
  'admin@expenseguard.com': {
    password: 'Test1234!',
    role: 'Sistem Admini',
    icon: 'shield',
    desc: 'Tüm sistem üzerinde tam teknik kontrol.',
    permissions: ['Kullanıcı Yönetimi', 'Sistem Ayarları', 'Audit Log', 'Rol Atama', 'Tenant Yönetimi', 'API Konfigürasyonu']
  },
  'yonetici@expenseguard.com': {
    password: 'Test1234!',
    role: 'Departman Yöneticisi',
    icon: 'briefcase',
    desc: 'Ekibinin gider fişlerini onaylar, departman bütçesini takip eder.',
    permissions: ['Ekip Fişleri', 'Onay / Red', 'Bütçe Raporu', 'Departman Analiz', 'Çalışan Performansı']
  },
  'calisan@expenseguard.com': {
    password: 'Test1234!',
    role: 'Çalışan',
    icon: 'user',
    desc: 'Yalnızca kendi fiş işlemlerini yönetir.',
    permissions: ['Kendi Fişleri', 'Fiş Yükleme', 'Durum Takibi']
  },
  'finans@expenseguard.com': {
    password: 'Test1234!',
    role: 'Finans & Denetim Uzmanı',
    icon: 'dollar',
    desc: 'Tüm şirket fişlerini, fraud analizlerini ve compliance raporlarını görür.',
    permissions: ['Tüm Şirket Fişleri', 'Fraud Analiz', 'Finansal Raporlar', 'Compliance Rapor', 'Risk Skoru Geçmişi', 'Bütçe Karşılaştırma']
  }
};

/* ── TAB SWITCHING ───────────────────────────────────────── */
const tabBtns   = document.querySelectorAll('.tab-btn');
const panels    = document.querySelectorAll('.tab-panel');
const indicator = document.querySelector('.tab-indicator');

tabBtns.forEach((btn, i) => {
  btn.addEventListener('click', () => {
    tabBtns.forEach(b => b.classList.remove('active'));
    panels.forEach(p => p.classList.remove('active'));
    btn.classList.add('active');
    panels[i].classList.add('active');
    indicator.style.left = (i * 50) + '%';
    clearFeedbacks();
  });
});

/* Handle #register hash in URL */
if (location.hash === '#register') {
  tabBtns[1]?.click();
}

/* ── TOGGLE PASSWORD ─────────────────────────────────────── */
const toggleLoginPw = document.getElementById('toggleLoginPw');
const loginPwField  = document.getElementById('loginPassword');
if (toggleLoginPw && loginPwField) {
  toggleLoginPw.addEventListener('click', () => {
    const show = loginPwField.type === 'password';
    loginPwField.type = show ? 'text' : 'password';
    toggleLoginPw.style.color = show ? 'var(--gold)' : '';
  });
}

/* ── PASSWORD STRENGTH METER ───────────────────────────── */
const regPwInput = document.getElementById('regPassword');
const pwFill     = document.getElementById('pwFill');
const pwLabel    = document.getElementById('pwLabel');

if (regPwInput && pwFill && pwLabel) {
  regPwInput.addEventListener('input', () => {
    const pw = regPwInput.value;
    let score = 0;
    if (pw.length >= 6) score++;
    if (pw.length >= 10) score++;
    if (/[A-Z]/.test(pw)) score++;
    if (/[0-9]/.test(pw)) score++;
    if (/[^A-Za-z0-9]/.test(pw)) score++;

    const levels = [
      { width: '0%',   color: 'transparent',  label: '', textColor: 'var(--text-muted)' },
      { width: '20%',  color: '#f87171',       label: 'Zayıf',       textColor: '#f87171' },
      { width: '40%',  color: '#fb923c',       label: 'Orta',        textColor: '#fb923c' },
      { width: '65%',  color: '#fbbf24',       label: 'Güçlü',       textColor: '#fbbf24' },
      { width: '85%',  color: '#34d399',       label: 'Güçlü',       textColor: '#34d399' },
      { width: '100%', color: '#10b981',       label: 'Çok Güçlü',   textColor: '#10b981' }
    ];
    const level = levels[Math.min(score, 5)];
    pwFill.style.width = level.width;
    pwFill.style.background = level.color;
    pwLabel.textContent = level.label;
    pwLabel.style.color = level.textColor;
  });
}

/* ── HELPERS ──────────────────────────────────────────────── */
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
function clearFeedbacks() {
  document.querySelectorAll('.auth-feedback').forEach(f => {
    f.className = 'auth-feedback'; f.textContent = ''; f.style.display = 'none';
  });
}
function showFeedback(el, msg, type) {
  el.textContent = msg;
  el.className = 'auth-feedback ' + type;
  el.style.display = 'block';
}
function resetBtn(btn, text) {
  btn.querySelector('span').textContent = text;
  btn.disabled = false;
}

/* ── API HEALTH CHECK ────────────────────────────────────── */
async function isApiAvailable() {
  try {
    const res = await fetch('http://localhost/health', { signal: AbortSignal.timeout(2000) });
    return res.ok;
  } catch {
    return false;
  }
}

/* ── LOGIN via API ───────────────────────────────────────── */
async function loginViaApi(email, pw) {
  const domain = email.split('@')[1] || 'acme.com.tr';
  const res = await fetch('http://localhost/api/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Tenant-Domain': domain
    },
    body: JSON.stringify({ email, password: pw })
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || 'Giriş başarısız.');
  }

  const data = await res.json();
  const token = data.token;

  const roleMap = {
    'Sistem Admini': { icon: 'shield', desc: 'Tüm sistem üzerinde tam teknik kontrol.', permissions: ['Kullanıcı Yönetimi', 'Sistem Ayarları', 'Audit Log', 'Rol Atama', 'Tenant Yönetimi', 'API Konfigürasyonu'] },
    'Departman Yöneticisi': { icon: 'briefcase', desc: 'Ekibinin gider fişlerini onaylar, departman bütçesini takip eder.', permissions: ['Ekip Fişleri', 'Onay / Red', 'Bütçe Raporu', 'Departman Analiz', 'Çalışan Performansı'] },
    'Çalışan': { icon: 'user', desc: 'Yalnızca kendi fiş işlemlerini yönetir.', permissions: ['Kendi Fişleri', 'Fiş Yükleme', 'Durum Takibi'] },
    'Finans & Denetim Uzmanı': { icon: 'dollar', desc: 'Tüm şirket fişlerini, fraud analizlerini ve compliance raporlarını görür.', permissions: ['Tüm Şirket Fişleri', 'Fraud Analiz', 'Finansal Raporlar', 'Compliance Rapor', 'Risk Skoru Geçmişi', 'Bütçe Karşılaştırma'] }
  };

  const userRoleName = data.user?.role || data.role || 'Çalışan';
  const mapped = roleMap[userRoleName] || { icon: 'user', desc: 'Sisteme hoş geldiniz.', permissions: [] };

  return {
    email,
    role: userRoleName,
    icon: mapped.icon,
    desc: mapped.desc,
    permissions: mapped.permissions,
    token: token,
    mode: 'api'
  };
}

/* ── LOGIN via DEMO (Offline Fallback) ───────────────────── */
function loginViaDemo(email, pw) {
  const account = DEMO_ACCOUNTS[email];
  if (!account) {
    throw new Error('Bu e-posta adresiyle kayıtlı demo hesap bulunamadı.');
  }
  if (account.password !== pw) {
    throw new Error('Şifre hatalı. Demo hesap şifresi: Test1234!');
  }

  return {
    email,
    role: account.role,
    icon: account.icon,
    desc: account.desc,
    permissions: account.permissions,
    token: null,
    mode: 'demo'
  };
}

/* ── UNIFIED LOGIN HANDLER ───────────────────────────────── */
async function performLogin(email, pw) {
  // 1) Önce API'yi dene
  const apiUp = await isApiAvailable();

  if (apiUp) {
    try {
      return await loginViaApi(email, pw);
    } catch (apiErr) {
      // API var ama giriş başarısız — hata fırlat
      throw apiErr;
    }
  }

  // 2) API yoksa demo hesapları dene
  return loginViaDemo(email, pw);
}

/* ── LOGIN FORM ──────────────────────────────────────────── */
const loginForm     = document.getElementById('loginForm');
const loginFeedback = document.getElementById('loginFeedback');
const loginSubmitBtn = document.getElementById('loginSubmitBtn');

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  clearFeedbacks();

  const email = document.getElementById('loginEmail').value.trim().toLowerCase();
  const pw    = document.getElementById('loginPassword').value;

  loginSubmitBtn.querySelector('span').textContent = 'Giriş yapılıyor...';
  loginSubmitBtn.disabled = true;
  await sleep(800);

  try {
    const result = await performLogin(email, pw);

    const modeLabel = result.mode === 'demo' ? ' (Demo Mod)' : '';
    showFeedback(loginFeedback, `Giriş başarılı!${modeLabel} Yönlendiriliyorsunuz...`, 'success');
    resetBtn(loginSubmitBtn, 'Giriş Yap');
    await sleep(600);

    // Store session
    localStorage.setItem('eg_session', JSON.stringify({
      email: result.email,
      role: result.role,
      icon: result.icon,
      loginTime: new Date().toISOString(),
      token: result.token,
      mode: result.mode
    }));

    showSuccessModal(result.email, result);
    // Bekleyen plan satın alma varsa, ödemeye yönlendir
    if (localStorage.getItem('eg_pending_plan')) {
      showFeedback(loginFeedback, 'Giriş başarılı! Ödeme sayfasına yönlendiriliyorsunuz...', 'success');
      await sleep(800);
      window.location.href = 'index.html#pricing';
      return;
    }
  } catch (err) {
    console.error(err);
    showFeedback(loginFeedback, err.message, 'error');
    resetBtn(loginSubmitBtn, 'Giriş Yap');
  }
});

/* ── REGISTER FORM ───────────────────────────────────────── */
const regForm     = document.getElementById('registerForm');
const regFeedback = document.getElementById('regFeedback');
const regSubmitBtn = document.getElementById('regSubmitBtn');

regForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  clearFeedbacks();

  const pw1 = document.getElementById('regPassword').value;
  const pw2 = document.getElementById('regPasswordConfirm').value;

  if (pw1 !== pw2) { showFeedback(regFeedback, 'Şifreler eşleşmiyor.', 'error'); return; }
  if (pw1.length < 6) { showFeedback(regFeedback, 'Şifre en az 6 karakter olmalıdır.', 'error'); return; }

  regSubmitBtn.querySelector('span').textContent = 'Oluşturuluyor...';
  regSubmitBtn.disabled = true;
  await sleep(1500);

  const name  = document.getElementById('regFirstName').value + ' ' + document.getElementById('regLastName').value;
  const email = document.getElementById('regEmail').value;
  const role  = document.getElementById('regRole');
  const roleName = role.options[role.selectedIndex].text;
  const roleVal  = role.value;

  const roleMap = {
    admin:    { icon: 'shield', perms: ['Kullanıcı Yönetimi','Sistem Ayarları','Audit Log','Rol Atama'] },
    manager:  { icon: 'briefcase', perms: ['Ekip Fişleri','Onay / Red','Bütçe Raporu','Departman Analiz'] },
    employee: { icon: 'user', perms: ['Kendi Fişleri','Fiş Yükleme','Durum Takibi'] },
    finance:  { icon: 'dollar', perms: ['Tüm Şirket Fişleri','Fraud Analiz','Finansal Raporlar','Compliance'] }
  };
  const info = roleMap[roleVal] || roleMap.employee;

  showFeedback(regFeedback, `Hoş geldiniz ${name}! Hesabınız "${roleName}" olarak oluşturuldu.`, 'success');
  resetBtn(regSubmitBtn, 'Üyelik Oluştur');
  await sleep(1000);

  localStorage.setItem('eg_session', JSON.stringify({
    email, role: roleName, icon: info.icon, loginTime: new Date().toISOString(), mode: 'demo'
  }));

  // Bekleyen plan satın alma varsa, ödemeye yönlendir
  if (localStorage.getItem('eg_pending_plan')) {
    showFeedback(regFeedback, 'Hesabınız oluşturuldu! Ödeme sayfasına yönlendiriliyorsunuz...', 'success');
    await sleep(800);
    window.location.href = 'index.html#pricing';
    return;
  }

  showSuccessModal(email, {
    role: roleName, icon: info.icon, pw: '••••••••',
    desc: 'Yeni hesabınız başarıyla oluşturuldu.',
    permissions: info.perms
  });
  regForm.reset();
});

/* ── DEMO CARD QUICK LOGIN ───────────────────────────────── */
document.querySelectorAll('.btn-demo-login').forEach(btn => {
  btn.addEventListener('click', async (e) => {
    e.stopPropagation();
    const card  = btn.closest('.demo-card');
    const email = card.dataset.email;
    const pw    = card.dataset.pw;

    // Switch to login tab
    tabBtns[0].click();
    await sleep(300);

    // Type email with animation
    const emailField = document.getElementById('loginEmail');
    const pwField    = document.getElementById('loginPassword');
    emailField.value = '';
    pwField.value    = '';

    for (const ch of email) { emailField.value += ch; await sleep(20); }
    await sleep(150);
    for (const ch of pw) { pwField.value += ch; await sleep(25); }
    await sleep(300);

    loginForm.dispatchEvent(new Event('submit'));
  });
});

document.querySelectorAll('.demo-card').forEach(card => {
  card.addEventListener('click', (e) => {
    if (e.target.closest('.btn-demo-login')) return;
    card.querySelector('.btn-demo-login').click();
  });
});

/* ── SUCCESS MODAL ───────────────────────────────────────── */
function showSuccessModal(email, account) {
  document.querySelector('.login-success-overlay')?.remove();

  const rc = {
    'Sistem Admini':           { bg: 'rgba(245,158,11,0.12)', color: '#f59e0b', border: 'rgba(245,158,11,0.3)' },
    'Departman Yöneticisi':    { bg: 'rgba(59,130,246,0.12)',  color: '#60a5fa', border: 'rgba(59,130,246,0.3)' },
    'Çalışan':                 { bg: 'rgba(52,211,153,0.12)',  color: '#34d399', border: 'rgba(52,211,153,0.3)' },
    'Finans & Denetim Uzmanı': { bg: 'rgba(167,139,250,0.12)', color: '#a78bfa', border: 'rgba(167,139,250,0.3)' }
  };
  const c = rc[account.role] || rc['Çalışan'];

  const permHTML = (account.permissions || []).map(p =>
    `<span style="background:${c.bg};color:${c.color};border:1px solid ${c.border};padding:4px 12px;border-radius:100px;font-size:0.72rem;font-weight:700">${p}</span>`
  ).join('');

  const svgIcons = {
    shield: '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><circle cx="12" cy="11" r="3"/></svg>',
    briefcase: '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 00-2-2h-4a2 2 0 00-2 2v2"/></svg>',
    user: '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    dollar: '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/></svg>'
  };
  const iconSvg = svgIcons[account.icon] || svgIcons.user;

  const overlay = document.createElement('div');
  overlay.className = 'login-success-overlay';
  overlay.innerHTML = `
    <div class="login-success-card">
      <div class="success-icon" style="color:${c.color}">${iconSvg}</div>
      <span class="success-role-badge" style="background:${c.bg};color:${c.color};border:1px solid ${c.border}">${account.role}</span>
      <h2>Giriş Başarılı!</h2>
      <p>${account.desc || 'Hesabınıza başarıyla giriş yaptınız.'}</p>
      <div class="user-info-box">
        <div class="user-info-row"><span class="label">E-posta</span><span class="value">${email}</span></div>
        <div class="user-info-row"><span class="label">Rol</span><span class="value">${account.role}</span></div>
        <div class="user-info-row"><span class="label">Giriş Zamanı</span><span class="value">${new Date().toLocaleString('tr-TR')}</span></div>
        <div class="user-info-row"><span class="label">Oturum</span><span class="value" style="color:#34d399">Aktif</span></div>
      </div>
      <div style="display:flex;flex-wrap:wrap;gap:6px;justify-content:center;margin-bottom:24px">${permHTML}</div>
      <button class="btn-dashboard" onclick="window.location.href='dashboard.html'">
        Dashboard'a Git
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M5 12h14M12 5l7 7-7 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </button>
      <button class="btn-close-modal" id="closeSuccessModal">Kapat</button>
    </div>`;

  document.body.appendChild(overlay);
  document.getElementById('closeSuccessModal').onclick = () => overlay.remove();
  overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') overlay.remove(); }, { once: true });
}

/* ── FORGOT PASSWORD MODAL ───────────────────────────────── */
const forgotPwModal = document.getElementById('forgotPwModal');
const closeForgotPw = document.getElementById('closeForgotPw');
const forgotLink = document.querySelector('.forgot-link');
const forgotPwForm = document.getElementById('forgotPwForm');
const forgotFeedback = document.getElementById('forgotFeedback');
const forgotSubmitBtn = document.getElementById('forgotSubmitBtn');

if (forgotLink && forgotPwModal) {
  forgotLink.addEventListener('click', (e) => {
    e.preventDefault();
    forgotPwModal.classList.add('active');
  });

  closeForgotPw.addEventListener('click', () => {
    forgotPwModal.classList.remove('active');
  });

  forgotPwForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    forgotFeedback.style.display = 'none';
    const email = document.getElementById('forgotEmail').value.trim();
    
    forgotSubmitBtn.querySelector('span').textContent = 'Gönderiliyor...';
    forgotSubmitBtn.disabled = true;

    try {
      const res = await fetch('http://localhost/api/auth/forgot-password', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Tenant-Domain': email.split('@')[1] || 'acme.com.tr'
        },
        body: JSON.stringify({ email })
      });

      const data = await res.json();

      if (res.ok) {
        showFeedback(forgotFeedback, data.message, 'success');
        setTimeout(() => forgotPwModal.classList.remove('active'), 3000);
      } else {
        showFeedback(forgotFeedback, data.error || 'İşlem başarısız.', 'error');
      }
    } catch (err) {
      // Demo modda şifre sıfırlama simülasyonu
      showFeedback(forgotFeedback, 'Demo mod — Şifre sıfırlama bağlantısı simüle edildi. (API offline)', 'success');
      setTimeout(() => forgotPwModal.classList.remove('active'), 3000);
    } finally {
      resetBtn(forgotSubmitBtn, 'Sıfırlama Bağlantısı Gönder');
    }
  });
}
