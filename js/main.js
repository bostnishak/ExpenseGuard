/* ════════════════════════════════════════════════════
   EXPENSEGUARD — MAIN.JS  (v4 — production-ready)
═════════════════════════════════════════════════════ */
'use strict';

/* ── YARDIMCI: ID'ye smooth scroll ──────────────────── */
function goTo(id) {
  const el = document.getElementById(id);
  if (!el) return;
  const top = el.getBoundingClientRect().top + window.pageYOffset - 80;
  window.scrollTo({ top, behavior: 'smooth' });
}

/* ── OTURUM DURUMUNA GÖRE NAVBAR GÜNCELLE ────────────── */
(function updateNavForSession() {
  const raw = localStorage.getItem('eg_session');
  if (!raw) return;
  try {
    const sess = JSON.parse(raw);
    const navActions = document.getElementById('navActions');
    if (!navActions) return;
    navActions.innerHTML = `
      <span style="font-size:.82rem;color:#c4a882;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${sess.email || sess.role || ''}</span>
      <a href="dashboard.html" class="btn-ghost" style="margin-left:4px">Dashboard</a>
      <button onclick="localStorage.removeItem('eg_session');location.reload();" 
        class="btn-ghost" style="font-size:.8rem;color:#8b7355;border-color:rgba(139,115,85,.2)">Çıkış</button>
    `;
  } catch { /* geçersiz session */ }
})();

/* ── TÜM #HASH LİNKLERİ ─────────────────────────────── */
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', e => {
    const href = a.getAttribute('href');
    if (!href || href === '#' || href === '#!') return;
    const target = document.querySelector(href);
    if (target) {
      e.preventDefault();
      const top = target.getBoundingClientRect().top + window.pageYOffset - 80;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  });
});

/* ── NAVBAR SCROLL ───────────────────────────────────── */
const navbar = document.getElementById('navbar');
if (navbar) {
  window.addEventListener('scroll', () => {
    navbar.classList.toggle('scrolled', window.scrollY > 40);
  }, { passive: true });
}

/* ── HAMBURGEr ───────────────────────────────────────── */
const hamburger  = document.getElementById('hamburger');
const navLinksEl = document.getElementById('navLinks');
if (hamburger && navLinksEl) {
  hamburger.addEventListener('click', () => {
    navLinksEl.classList.toggle('open');
    const spans = hamburger.querySelectorAll('span');
    const isOpen = navLinksEl.classList.contains('open');
    spans[0].style.transform = isOpen ? 'rotate(45deg) translate(5px,5px)' : '';
    spans[1].style.opacity   = isOpen ? '0' : '';
    spans[2].style.transform = isOpen ? 'rotate(-45deg) translate(5px,-5px)' : '';
  });
  navLinksEl.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => {
      navLinksEl.classList.remove('open');
      hamburger.querySelectorAll('span').forEach(s => { s.style.transform = ''; s.style.opacity = ''; });
    });
  });
}

/* ── SCROLL TOP BUTONU ───────────────────────────────── */
const scrollTopBtn = document.getElementById('scrollTop');
if (scrollTopBtn) {
  window.addEventListener('scroll', () => {
    scrollTopBtn.classList.toggle('visible', window.scrollY > 400);
  }, { passive: true });
  scrollTopBtn.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));
}

/* ── ACTIVE NAV HIGHLIGHT ────────────────────────────── */
const pageSections = document.querySelectorAll('section[id]');
const navAnchorEls = document.querySelectorAll('.nav-links a');
window.addEventListener('scroll', () => {
  let current = '';
  pageSections.forEach(sec => {
    if (window.scrollY >= sec.offsetTop - 120) current = sec.id;
  });
  navAnchorEls.forEach(a => {
    a.style.color = a.getAttribute('href') === `#${current}` ? 'var(--gold-light)' : '';
  });
}, { passive: true });

/* ── COUNTER ANIMATION ───────────────────────────────── */
function animateCounters() {
  document.querySelectorAll('.stat-value[data-target]').forEach(el => {
    const target    = parseFloat(el.dataset.target);
    const isDecimal = target % 1 !== 0;
    let current = 0;
    const step  = target / 80;
    const timer = setInterval(() => {
      current = Math.min(current + step, target);
      el.textContent = isDecimal ? current.toFixed(1) : Math.floor(current).toLocaleString();
      if (current >= target) clearInterval(timer);
    }, 16);
  });
}
const heroEl = document.getElementById('hero');
if (heroEl) {
  new IntersectionObserver((entries, obs) => {
    entries.forEach(e => { if (e.isIntersecting) { animateCounters(); obs.disconnect(); } });
  }, { threshold: 0.3 }).observe(heroEl);
}

/* ── SCROLL REVEAL ───────────────────────────────────── */
const revealObs = new IntersectionObserver(entries => {
  entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('aos-in'); });
}, { threshold: 0.1, rootMargin: '0px 0px -36px 0px' });
document.querySelectorAll(
  '.feature-card, .arch-layer, .cia-card, .rbac-role, .pricing-card, .ai-step, .section-header, .roi-card, .testimonial-card'
).forEach(el => { el.setAttribute('data-aos', 'true'); revealObs.observe(el); });

/* ── ROI COUNTER ANIMATION ──────────────────────────── */
const roiSection = document.getElementById('roi');
if (roiSection) {
  new IntersectionObserver((entries, obs) => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        document.querySelectorAll('.roi-value[data-target]').forEach(el => {
          const target = parseFloat(el.dataset.target);
          let current = 0;
          const step = target / 60;
          const timer = setInterval(() => {
            current = Math.min(current + step, target);
            el.textContent = Math.floor(current);
            if (current >= target) { el.textContent = target; clearInterval(timer); }
          }, 20);
        });
        obs.disconnect();
      }
    });
  }, { threshold: 0.3 }).observe(roiSection);
}

/* ── PARALLAX ORBs ───────────────────────────────────── */
window.addEventListener('scroll', () => {
  const y = window.scrollY;
  const o1 = document.querySelector('.orb-1');
  const o2 = document.querySelector('.orb-2');
  const o3 = document.querySelector('.orb-3');
  if (o1) o1.style.transform = `translateY(${y * 0.14}px)`;
  if (o2) o2.style.transform = `translateY(${y * 0.07}px)`;
  if (o3) o3.style.transform = `translateY(${-y * 0.05}px)`;
}, { passive: true });

/* ── BILLING TOGGLE ──────────────────────────────────── */
const billingSwitch = document.getElementById('billingSwitch');
if (billingSwitch) {
  billingSwitch.addEventListener('change', () => {
    const annual = billingSwitch.checked;
    document.querySelectorAll('.monthly-price').forEach(el => el.style.display = annual ? 'none' : 'inline');
    document.querySelectorAll('.annual-price').forEach(el  => el.style.display = annual ? 'inline' : 'none');
  });
}

/* ── CONTACT FORM (Formspree real integration) ────────────────── */
const contactForm = document.getElementById('contactForm');
if (contactForm) {
  const formSuccess = document.getElementById('formSuccess');
  const submitBtn   = document.getElementById('submitBtn');
  contactForm.addEventListener('submit', async e => {
    e.preventDefault();
    const span = submitBtn.querySelector('span');
    const originalText = span.textContent;
    span.textContent  = 'Gönderiliyor...';
    submitBtn.disabled = true;
    try {
      const res = await fetch(contactForm.action, {
        method: 'POST',
        body: new FormData(contactForm),
        headers: { 'Accept': 'application/json' }
      });
      if (res.ok) {
        contactForm.reset();
        if (formSuccess) {
          formSuccess.style.cssText = '';
          formSuccess.querySelector('p').textContent = 'Talebiniz alındı! 24 saat içinde sizinle iletişime geçeceğiz.';
          formSuccess.style.display = 'flex';
          setTimeout(() => { formSuccess.style.display = 'none'; }, 8000);
        }
      } else {
        const data = await res.json().catch(() => ({}));
        const errMsg = data?.errors?.map(err => err.message).join(', ') || 'Gönderim hatası. Lütfen tekrar deneyin.';
        if (formSuccess) {
          formSuccess.style.cssText = 'display:flex;background:rgba(248,113,113,0.1);border-color:rgba(248,113,113,0.3);color:var(--danger)';
          formSuccess.querySelector('p').textContent = errMsg;
          setTimeout(() => { formSuccess.style.display = 'none'; }, 5000);
        }
      }
    } catch {
      if (formSuccess) {
        formSuccess.style.cssText = 'display:flex;background:rgba(248,113,113,0.1);border-color:rgba(248,113,113,0.3);color:var(--danger)';
        formSuccess.querySelector('p').textContent = 'Bağlantı hatası. İnternet bağlantınızı kontrol edip tekrar deneyin.';
        setTimeout(() => { formSuccess.style.display = 'none'; }, 5000);
      }
    }
    span.textContent  = originalText;
    submitBtn.disabled = false;
  });
}

/* ── HERO BADGE TYPING ───────────────────────────────── */
const badgeSpan = document.querySelector('.hero-badge span:last-child');
if (badgeSpan) {
  const txt = badgeSpan.textContent;
  badgeSpan.textContent = '';
  let i = 0;
  const type = () => { if (i < txt.length) { badgeSpan.textContent += txt[i++]; setTimeout(type, 38); } };
  setTimeout(type, 900);
}

/* ── FRAUD CARD DEMO (AI section) ────────────────────── */
const btnReject = document.querySelector('.btn-reject');
const btnReview = document.querySelector('.btn-review');
if (btnReject) {
  btnReject.addEventListener('click', () => {
    btnReject.textContent = 'Reddedildi';
    btnReject.style.background = 'rgba(248,113,113,0.28)';
    setTimeout(() => { btnReject.textContent = 'Reddet'; btnReject.style.background = ''; }, 2500);
  });
}
if (btnReview) {
  btnReview.addEventListener('click', () => {
    btnReview.textContent = 'Kuyruğa Alındı';
    btnReview.style.background = 'rgba(245,158,11,0.28)';
    setTimeout(() => { btnReview.textContent = 'İnceleye Al'; btnReview.style.background = ''; }, 2500);
  });
}

/* ════════════════════════════════════════════════════
   BUTON İŞLEVSELLİKLERİ
═════════════════════════════════════════════════════ */

/* ── FİYATLANDIRMA PLANI BUTONLARI ─────────────────── */
document.querySelectorAll('.btn-plan').forEach(btn => {
  btn.addEventListener('click', e => {
    e.preventDefault();
    const card = btn.closest('.pricing-card');
    const planName = card?.querySelector('.plan-name')?.textContent?.trim() || '';
    // Görünür fiyatı al (monthly veya annual)
    const amountEl = card?.querySelector('.annual-price[style*="none"]') 
      ? card?.querySelector('.monthly-price') 
      : (card?.querySelector('.annual-price') || card?.querySelector('.monthly-price'));
    const amount = amountEl?.textContent?.trim() || '';
    const planPrice = amount ? `₺${amount}/ay` : '';

    // Oturum kontrolü
    const session = localStorage.getItem('eg_session');
    if (!session) {
      // Plan bilgisini sakla ve login'e yönlendir
      localStorage.setItem('eg_pending_plan', JSON.stringify({ name: planName, price: planPrice }));
      window.location.href = 'login.html#register';
      return;
    }

    // Oturum varsa direkt ödeme modalını aç
    openCheckoutModal(planName, planPrice);
  });
});

/* ── SAYFA YÜKLENDIĞINDE BEKLEYEN PLAN KONTROLÜ ───── */
(function checkPendingPlan() {
  const session = localStorage.getItem('eg_session');
  const pending = localStorage.getItem('eg_pending_plan');
  if (session && pending) {
    try {
      const plan = JSON.parse(pending);
      localStorage.removeItem('eg_pending_plan');
      // Küçük gecikme ile sayfanın yüklenmesini bekle
      setTimeout(() => {
        goTo('pricing');
        setTimeout(() => openCheckoutModal(plan.name, plan.price), 600);
      }, 400);
    } catch { localStorage.removeItem('eg_pending_plan'); }
  }
})();

/* ── CHECKOUT MODAL ──────────────────────────────────── */
function openCheckoutModal(planName, planPrice) {
  document.getElementById('__checkoutModal')?.remove();
  const overlay = document.createElement('div');
  overlay.id = '__checkoutModal';
  Object.assign(overlay.style, {
    position:'fixed', inset:'0', zIndex:'9999',
    background:'rgba(0,0,0,.85)', backdropFilter:'blur(12px)',
    display:'flex', alignItems:'center', justifyContent:'center'
  });
  overlay.innerHTML = `
    <div style="background:#1c1109;border:1px solid rgba(245,158,11,.22);border-radius:20px;
      width:min(480px,93vw);box-shadow:0 24px 72px rgba(0,0,0,.7);position:relative;overflow:hidden">
      <div style="position:absolute;top:0;left:0;right:0;height:3px;
        background:linear-gradient(90deg,#f59e0b,#f97316,#fb7185)"></div>
      <div style="padding:1.5rem 1.5rem .8rem;border-bottom:1px solid rgba(255,175,50,.09);
        display:flex;align-items:center;justify-content:space-between">
        <strong style="font-size:1rem">Plan Sat\u0131n Al</strong>
        <button id="__checkoutClose" style="background:rgba(255,175,50,.07);border:1px solid rgba(255,175,50,.15);
          color:#c4a882;border-radius:8px;width:34px;height:34px;cursor:pointer;font-size:1.2rem;
          display:flex;align-items:center;justify-content:center">\u00d7</button>
      </div>
      <div style="padding:1.5rem">
        <div style="background:rgba(245,158,11,.05);border:1px solid rgba(245,158,11,.15);
          border-radius:12px;padding:1.2rem;margin-bottom:1.2rem;text-align:center">
          <div style="font-size:.8rem;color:#c4a882;margin-bottom:.3rem">Se\u00e7ilen Plan</div>
          <div style="font-size:1.4rem;font-weight:800;color:#f5f0e8">${planName}</div>
          <div style="font-size:1.1rem;font-weight:700;color:#f59e0b;margin-top:.3rem">${planPrice}</div>
        </div>
        <form id="__checkoutForm" style="display:flex;flex-direction:column;gap:.9rem">
          <div>
            <label style="font-size:.8rem;color:#c4a882;display:block;margin-bottom:.35rem">Kart Numaras\u0131</label>
            <input type="text" maxlength="19" placeholder="0000 0000 0000 0000" required
              style="width:100%;padding:.7rem .9rem;background:rgba(15,10,6,.6);border:1px solid rgba(245,158,11,.15);
              border-radius:10px;color:#f5f0e8;font-size:.9rem;font-family:monospace;outline:none"
              oninput="this.value=this.value.replace(/[^0-9]/g,'').replace(/(\\d{4})(?=\\d)/g,'$1 ')" />
          </div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:.9rem">
            <div>
              <label style="font-size:.8rem;color:#c4a882;display:block;margin-bottom:.35rem">Son Kullanma</label>
              <input type="text" maxlength="5" placeholder="AA/YY" required
                style="width:100%;padding:.7rem .9rem;background:rgba(15,10,6,.6);border:1px solid rgba(245,158,11,.15);
                border-radius:10px;color:#f5f0e8;font-size:.9rem;outline:none"
                oninput="this.value=this.value.replace(/[^0-9]/g,'').replace(/(\\d{2})(?=\\d)/g,'$1/')" />
            </div>
            <div>
              <label style="font-size:.8rem;color:#c4a882;display:block;margin-bottom:.35rem">CVV</label>
              <input type="password" maxlength="4" placeholder="\u2022\u2022\u2022" required
                style="width:100%;padding:.7rem .9rem;background:rgba(15,10,6,.6);border:1px solid rgba(245,158,11,.15);
                border-radius:10px;color:#f5f0e8;font-size:.9rem;outline:none" />
            </div>
          </div>
          <div>
            <label style="font-size:.8rem;color:#c4a882;display:block;margin-bottom:.35rem">Kart \u00dczerindeki \u0130sim</label>
            <input type="text" placeholder="Ad Soyad" required
              style="width:100%;padding:.7rem .9rem;background:rgba(15,10,6,.6);border:1px solid rgba(245,158,11,.15);
              border-radius:10px;color:#f5f0e8;font-size:.9rem;outline:none" />
          </div>
          <button type="submit" style="width:100%;padding:.85rem;background:linear-gradient(135deg,#f59e0b,#f97316);
            color:#0f0a06;border:none;border-radius:12px;font-size:.95rem;font-weight:800;cursor:pointer;
            margin-top:.4rem;transition:all .3s">
            \u00d6demeyi Tamamla
          </button>
          <div style="display:flex;align-items:center;justify-content:center;gap:.6rem;
            font-size:.75rem;color:#8b7355;margin-top:.2rem">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
            <span>256-bit SSL ile korunan g\u00fcvenli \u00f6deme</span>
          </div>
        </form>
      </div>
    </div>`;
  document.body.appendChild(overlay);
  document.getElementById('__checkoutClose').onclick = () => overlay.remove();
  overlay.onclick = e => { if (e.target === overlay) overlay.remove(); };
  document.addEventListener('keydown', e => { if (e.key === 'Escape') overlay.remove(); }, { once: true });
  document.getElementById('__checkoutForm').onsubmit = e => {
    e.preventDefault();
    const submitBtn = e.target.querySelector('button[type=submit]');
    submitBtn.textContent = '\u0130\u015fleniyor...';
    submitBtn.disabled = true;
    setTimeout(() => {
      // Planı session'a kaydet
      try {
        const sess = JSON.parse(localStorage.getItem('eg_session') || '{}');
        sess.plan = planName;
        sess.planDate = new Date().toISOString();
        localStorage.setItem('eg_session', JSON.stringify(sess));
        var userEmail = sess.email || '';
      } catch { var userEmail = ''; }

      overlay.querySelector('div > div').innerHTML = `
        <div style="padding:3rem 1.5rem;text-align:center">
          <div style="width:64px;height:64px;border-radius:50%;background:rgba(52,211,153,.12);
            display:flex;align-items:center;justify-content:center;margin:0 auto 1.2rem">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#34d399" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/></svg>
          </div>
          <h2 style="font-size:1.3rem;margin-bottom:.5rem;color:#f5f0e8">\u00d6deme Ba\u015far\u0131l\u0131!</h2>
          <p style="color:#c4a882;font-size:.88rem;margin-bottom:.4rem">
            <strong>${planName}</strong> plan\u0131n\u0131z aktif edildi.
          </p>
          ${userEmail ? '<p style="color:#8b7355;font-size:.78rem;margin-bottom:1.2rem">Hesap: <strong style="color:#c4a882">' + userEmail + '</strong></p>' : ''}
          <div style="background:rgba(245,158,11,.06);border:1px solid rgba(245,158,11,.15);
            border-radius:10px;padding:.7rem 1rem;margin-bottom:1.5rem;display:inline-flex;align-items:center;gap:.5rem">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2"><path d="M12 2l2.4 7.2L22 12l-7.6 2.8L12 22l-2.4-7.2L2 12l7.6-2.8z"/></svg>
            <span style="color:#f59e0b;font-weight:700;font-size:.85rem">Abonelik Aktif ✓</span>
          </div>
          <br/>
          <button onclick="document.getElementById('__checkoutModal').remove();window.location.href='dashboard.html'"
            style="padding:.75rem 2rem;background:linear-gradient(135deg,#f59e0b,#f97316);
            color:#0f0a06;border:none;border-radius:12px;font-weight:800;cursor:pointer;font-size:.9rem">
            Dashboard'a Git
          </button>
        </div>`;
    }, 2000);
  };
}

/* ── COOKIE CONSENT BANNER (3.1 & 3.7) ───────────────── */
(function initCookieBanner() {
  const banner = document.getElementById('cookieBanner');
  if (!banner) return;
  
  const consent = localStorage.getItem('eg_cookie_consent');
  if (!consent) {
    setTimeout(() => {
      banner.classList.add('visible');
    }, 1500);
  }

  const saveConsent = (type) => {
    localStorage.setItem('eg_cookie_consent', type);
    banner.classList.remove('visible');
  };

  document.getElementById('cookieAcceptAll')?.addEventListener('click', () => saveConsent('all'));
  document.getElementById('cookieEssentialOnly')?.addEventListener('click', () => saveConsent('essential'));
  document.getElementById('cookieReject')?.addEventListener('click', () => saveConsent('rejected'));
})();

/* ── FOOTER NAV BAĞLANTILARI ─────────────────────────── */
const footerMap = {
  'Özellikler':  'features',
  'Mimari':      'architecture',
  'AI Motor':    'ai-engine',
  'Fiyatlar':    'pricing',
  'CIA Triadı':  'security',
  'RBAC Rolleri':'security',
  'Audit Trail': 'security',
  'KVKK Uyumu':  'security',
  'ASP.NET Core':'architecture',
  'Python FastAPI':'architecture',
  'Flutter':       'architecture',
  'Docker':        'architecture',
};
document.querySelectorAll('.footer-links a').forEach(a => {
  const id = footerMap[a.textContent.trim()];
  if (id) {
    a.addEventListener('click', e => { e.preventDefault(); goTo(id); });
  }
});

/* ── TEKNOLOJİ BADGE'LERI ────────────────────────────── */
document.querySelectorAll('.tech-logo').forEach(logo => {
  logo.style.cursor = 'pointer';
  logo.title = 'Mimari bölümünü gör';
  logo.addEventListener('click', () => goTo('architecture'));
});

/* ── URL HASH DESTEĞI ────────────────────────────────── */
window.addEventListener('load', () => {
  if (location.hash) setTimeout(() => goTo(location.hash.slice(1)), 300);
});

/* ── EXIT-INTENT POPUP ───────────────────────────────── */
(function exitIntentPopup() {
  // Skip if already shown this session or user is logged in
  if (sessionStorage.getItem('eg_exit_shown')) return;
  if (localStorage.getItem('eg_session')) return;

  let shown = false;
  document.addEventListener('mouseout', e => {
    if (shown) return;
    if (e.clientY > 5) return; // only trigger when mouse leaves from top
    if (e.relatedTarget || e.toElement) return;
    shown = true;
    sessionStorage.setItem('eg_exit_shown', '1');

    const overlay = document.createElement('div');
    overlay.className = 'exit-popup-overlay';
    overlay.innerHTML = `
      <div class="exit-popup">
        <button class="exit-popup-close" aria-label="Kapat">&times;</button>
        <div class="exit-popup-icon">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--gold)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 2l2.4 7.2L22 12l-7.6 2.8L12 22l-2.4-7.2L2 12l7.6-2.8z"/>
          </svg>
        </div>
        <h3>Çıkmadan Önce Demoyu Deneyin!</h3>
        <p>ExpenseGuard'ın AI destekli fraud tespitini ve OCR fiş taramayı canlı dashboard'da deneyimleyin. Kayıt gerekmez.</p>
        <a href="login.html" class="btn-primary btn-lg">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/><path d="M10 8l6 4-6 4V8z" fill="currentColor"/></svg>
          Ücretsiz Demo'ya Git
        </a>
        <button class="btn-skip">Hayır, teşekkürler</button>
      </div>
    `;
    document.body.appendChild(overlay);

    const close = () => overlay.remove();
    overlay.querySelector('.exit-popup-close').onclick = close;
    overlay.querySelector('.btn-skip').onclick = close;
    overlay.onclick = e => { if (e.target === overlay) close(); };
    document.addEventListener('keydown', e => { if (e.key === 'Escape') close(); }, { once: true });
  });
})();
