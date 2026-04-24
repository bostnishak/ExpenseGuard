/* ══════════════════════════════════════════════════════════
   ExpenseGuard — Dashboard JavaScript
   API entegrasyonlu yönetici paneli
   Demo mod: API olmadan simüle veri kullanır
══════════════════════════════════════════════════════════ */
'use strict';

// ── CONFIG ───────────────────────────────────────────────────
const API_BASE = 'http://localhost';
let AUTH_TOKEN = null;
let TENANT_DOMAIN = '';
let currentUser = null;

// ── SECURITY HELPERS (XSS Prevention) ────────────────────────
function escapeHTML(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// ── API HELPERS ───────────────────────────────────────────────
function isDemo() {
  return false; // Artık her zaman gerçek API kullanılacak (Faz 4)
}

async function apiFetch(path, opts = {}) {
  opts.headers = {
    'X-Tenant-Domain': TENANT_DOMAIN,
    ...(opts.headers || {})
  };
  return window.egApi.fetch(path.replace('/api', ''), opts);
}



// ── TOAST ──────────────────────────────────────────────────────
function showToast(msg, type = 'success') {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className   = `toast ${type}`;
  t.style.display = 'block';
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.style.display = 'none'; }, 3500);
}

// ── SECTION NAVIGATION ─────────────────────────────────────────
function switchSection(name) {
  document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
  document.getElementById(`section-${name}`).classList.add('active');
  document.getElementById(`nav-${name}`).classList.add('active');
  document.getElementById('pageTitle').textContent = {
    overview:  'Genel Bakış',
    receipts:  'Fişler',
    highrisk:  'Yüksek Risk',
    budgets:   'Bütçeler',
    upload:    'Fiş Yükle',
    analytics: 'Analitik',
    billing:   'Abonelik Yönetimi'
  }[name] || name;
  window.currentSection = name;
  loadSection(name);
}

document.querySelectorAll('.nav-item').forEach(btn => {
  btn.addEventListener('click', () => {
    switchSection(btn.dataset.section);
    // Mobilde sidebar'ı kapat
    if (window.innerWidth <= 960) closeSidebar();
  });
});

// ── SIDEBAR TOGGLE ───────────────────────────────────────────────
const sidebar        = document.getElementById('sidebar');
const sidebarOverlay = document.getElementById('sidebarOverlay');

function openSidebar() {
  sidebar.classList.add('open');
  sidebarOverlay.classList.add('active');
}
function closeSidebar() {
  sidebar.classList.remove('open');
  sidebarOverlay.classList.remove('active');
}
function toggleSidebar() {
  sidebar.classList.contains('open') ? closeSidebar() : openSidebar();
}

document.getElementById('sidebarToggle').addEventListener('click', toggleSidebar);
sidebarOverlay.addEventListener('click', closeSidebar);

// ── SESSION INIT (from login.html) ─────────────────────────────
(function initSession() {
  const raw = localStorage.getItem('eg_session');
  if (!raw) { window.location.replace('login.html'); return; }
  window.history.pushState(null, null, window.location.href);
  window.onpopstate = function () { window.history.go(1); };
  try {
    const session = JSON.parse(raw);
    currentUser = { fullName: session.role || 'Kullanıcı', role: session.role, email: session.email };
    TENANT_DOMAIN = session.email ? (session.email.split('@')[1] || 'acme.com.tr') : 'demo.com';
    AUTH_TOKEN = session.token || null; // <--- GERÇEK API TOKENI BURADAN ALINIR
    
    document.getElementById('userName').textContent = session.role || 'Kullanıcı';
    document.getElementById('userRole').textContent = session.email || '';
    document.getElementById('userAvatar').textContent = (session.role?.[0] || session.email?.[0] || 'U').toUpperCase();

    // ── White-Label (Faz 2) Tema & Logo Enjeksiyonu ──
    if (session.themeColor) {
      document.documentElement.style.setProperty('--blue-600', session.themeColor);
      document.documentElement.style.setProperty('--blue-700', session.themeColor);
      document.documentElement.style.setProperty('--primary', session.themeColor);
      // Butonları vb renklendirmek için
    }
    
    const brandNameEl = document.getElementById('brandName');
    if (session.logoUrl && brandNameEl) {
       brandNameEl.innerHTML = `<img src="${escapeHTML(session.logoUrl)}" alt="Company Logo" style="height:32px;display:inline-block">`;
    } else if (session.companyName && brandNameEl) {
       brandNameEl.textContent = session.companyName;
    }

    // Yetki Kontrolleri (UI Görünürlüğü)
    if (session.role === 'Sistem Admini') {
      document.getElementById('nav-billing').style.display = 'flex';
      document.getElementById('exportCsvBtn').style.display = 'inline-flex';
    } else if (session.role === 'Finans & Denetim Uzmanı') {
      document.getElementById('exportCsvBtn').style.display = 'inline-flex';
    }

    checkApiStatus();
    loadSection('overview');
  } catch {
    window.location.href = 'login.html';
  }
})();

// ── EXPORT CSV ──────────────────────────────────────────────────
document.getElementById('exportCsvBtn').addEventListener('click', async () => {
  if (isDemo()) return showToast('Demo modda Excel indirilemez.', 'error');
  try {
    const res = await fetch(`${API_BASE}/api/receipts/export-csv`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${AUTH_TOKEN}`,
        'X-Tenant-Domain': TENANT_DOMAIN
      }
    });
    if (!res.ok) throw new Error('Dışa aktarma başarısız');
    const blob = await res.blob();
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `ExpenseGuard_Fisler_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    a.remove();
    showToast('Excel başarıyla indirildi.', 'success');
  } catch (err) {
    console.error(err);
    showToast('Excel indirilirken hata oluştu.', 'error');
  }
});

// ── LOGOUT ─────────────────────────────────────────────────────
document.getElementById('logoutBtn').addEventListener('click', () => {
  localStorage.removeItem('eg_session');
  window.location.replace('login.html');
});

// ── API STATUS ─────────────────────────────────────────────────
async function checkApiStatus() {
  const dot  = document.querySelector('.status-dot');
  const text = document.getElementById('apiStatusText');
  try {
    await fetch(`${API_BASE}/health`, { signal: AbortSignal.timeout(3000) });
    dot.className  = 'status-dot online';
    text.textContent = 'API Bağlı';
    // Remove offline banner if it exists
    document.getElementById('offlineBanner')?.remove();
  } catch {
    dot.className  = 'status-dot offline';
    text.textContent = 'API Offline (Demo)';
    showOfflineBanner();
  }
}

function showOfflineBanner() {
  if (document.getElementById('offlineBanner')) return;
  const banner = document.createElement('div');
  banner.id = 'offlineBanner';
  banner.style.cssText = `
    position:fixed;top:0;left:0;right:0;z-index:10001;
    background:linear-gradient(90deg,rgba(245,158,11,0.15),rgba(249,115,22,0.15));
    border-bottom:1px solid rgba(245,158,11,0.3);
    padding:10px 20px;
    display:flex;align-items:center;justify-content:center;gap:10px;
    font-size:0.82rem;font-weight:600;color:#fbbf24;
    backdrop-filter:blur(12px);
  `;
  banner.innerHTML = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
    </svg>
    <span>API sunucusu çevrimdışı — Simüle demo verileri kullanılıyor</span>
    <button onclick="this.parentElement.remove()" style="background:none;border:1px solid rgba(245,158,11,0.3);border-radius:6px;color:#fbbf24;cursor:pointer;padding:2px 10px;font-size:0.75rem;margin-left:8px">Kapat</button>
  `;
  document.body.prepend(banner);
}

// ── SECTION LOADER ─────────────────────────────────────────────
async function loadSection(name) {
  if (name === 'overview')  await loadOverview();
  if (name === 'receipts')  await loadReceipts();
  if (name === 'highrisk')  await loadHighRisk();
  if (name === 'analytics') await loadAnalytics();
}

// ── REFRESH ─────────────────────────────────────────────────────
document.getElementById('refreshBtn').addEventListener('click', () => {
  loadSection(window.currentSection || 'overview');
  showToast('Veriler güncellendi');
});

// ══════════════════════════════════════════════════════════════
// SECTION: OVERVIEW
// ══════════════════════════════════════════════════════════════
let statusChartInst = null;
let trendChartInst  = null;

async function loadOverview() {
  let summary = { totalReceipts: 0, pendingCount: 0, approvedCount: 0, rejectedCount: 0, flaggedCount: 0, highRiskCount: 0, thisMonthSpend: 0 };
  let recentHighRisk = [];

  try {
    if (isDemo()) {
      // Demo modda eski mantık
      const data = await apiFetch('/api/receipts/my?pageSize=50');
      const receipts = data.items || data || [];
      summary = {
        totalReceipts: receipts.length,
        pendingCount:  receipts.filter(r => r.status === 'Pending').length,
        approvedCount: receipts.filter(r => r.status === 'Approved').length,
        rejectedCount: receipts.filter(r => r.status === 'Rejected').length,
        flaggedCount:  receipts.filter(r => r.status === 'Flagged').length,
        highRiskCount: receipts.filter(r => r.riskLevel === 'High').length,
        thisMonthSpend: receipts.filter(r => r.status !== 'Rejected').reduce((s,r) => s + r.amount, 0),
      };
      recentHighRisk = receipts.filter(r => r.riskLevel === 'High').slice(0, 5);
    } else {
      // Gerçek API
      const stats = await apiFetch('/dashboard/summary');
      summary = {
        totalReceipts: stats.totalReceipts,
        pendingCount: stats.pendingReceipts,
        approvedCount: stats.approvedReceipts,
        rejectedCount: stats.rejectedReceipts,
        flaggedCount: 0,
        highRiskCount: 0, // TODO: dashboard summary will return these later
        thisMonthSpend: stats.totalAmount
      };
      const recent = await apiFetch('/dashboard/recent-activity?count=5');
      recentHighRisk = recent.filter(r => r.riskLevel === 'High');
    }
  } catch (e) {
    console.error(e);
  }

  // KPIs
  document.getElementById('kpiTotal').textContent    = summary.totalReceipts;
  document.getElementById('kpiApproved').textContent = summary.approvedCount;
  document.getElementById('kpiHighRisk').textContent = summary.highRiskCount;
  document.getElementById('kpiMonthSpend').textContent = formatCurrency(summary.thisMonthSpend);

  // Badges
  document.getElementById('pendingBadge').textContent = summary.pendingCount;
  document.getElementById('riskBadge').textContent    = summary.highRiskCount;

  // Donut Chart — Durum Dağılımı
  const statusCtx = document.getElementById('statusChart').getContext('2d');
  if (statusChartInst) statusChartInst.destroy();
  statusChartInst = new Chart(statusCtx, {
    type: 'doughnut',
    data: {
      labels: ['Onaylı','Reddedildi','Bayraklı','Bekliyor','AI İşliyor'],
      datasets: [{
        data: [summary.approvedCount, summary.rejectedCount, summary.flaggedCount, summary.pendingCount, summary.totalReceipts - summary.approvedCount - summary.rejectedCount - summary.flaggedCount - summary.pendingCount],
        backgroundColor: ['#10b981','#ef4444','#f59e0b','#6366f1','#a855f7'],
        borderWidth: 2, borderColor: '#111827',
      }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { position: 'bottom', labels: { color:'#8b9cc8', font:{size:11}, padding:10 } } },
      cutout: '65%',
    },
  });

  // Line Chart — Aylık Trend (demo)
  const months = ['Kas','Ara','Oca','Şub','Mar','Nis'];
  const spends = [42000, 67000, 55000, 89000, 71000, Math.round(summary.thisMonthSpend)];
  const trendCtx = document.getElementById('trendChart').getContext('2d');
  if (trendChartInst) trendChartInst.destroy();
  trendChartInst = new Chart(trendCtx, {
    type: 'line',
    data: {
      labels: months,
      datasets: [{
        label: 'Harcama (TRY)',
        data: spends,
        borderColor: '#6366f1',
        backgroundColor: 'rgba(99,102,241,0.1)',
        borderWidth: 2, fill: true, tension: .4,
        pointBackgroundColor: '#6366f1',
      }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#8b9cc8' } },
        y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#8b9cc8', callback: v => '₺' + v.toLocaleString() } },
      },
    },
  });

  // Recent High Risk
  const container = document.getElementById('recentHighRiskList');
  if (!recentHighRisk.length) {
    container.innerHTML = '<div class="empty-state"><div class="icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/></svg></div><p>Yüksek riskli fiş yok</p></div>';
    return;
  }
  container.innerHTML = recentHighRisk.map(r => receiptRowHTML(r)).join('');
  attachReceiptClickHandlers(container, recentHighRisk);
}

// ══════════════════════════════════════════════════════════════
// SECTION: RECEIPTS
// ══════════════════════════════════════════════════════════════
let allReceipts = [];

async function loadReceipts() {
  const container = document.getElementById('receiptsList');
  container.innerHTML = `
    <div class="skeleton-row" style="height:64px;border-radius:12px;background:var(--bg-card);margin-bottom:8px;animation:pulse 1.5s infinite"></div>
    <div class="skeleton-row" style="height:64px;border-radius:12px;background:var(--bg-card);margin-bottom:8px;animation:pulse 1.5s infinite"></div>
    <div class="skeleton-row" style="height:64px;border-radius:12px;background:var(--bg-card);animation:pulse 1.5s infinite"></div>
  `;

  try {
    const data = await apiFetch('/api/receipts/my?pageSize=100');
    allReceipts = data.items || data;
  } catch (e) {
    console.error(e);
    allReceipts = [];
  }

  renderReceipts();
}

function renderReceipts() {
  const statusFilter = document.getElementById('statusFilter').value;
  const search       = document.getElementById('searchInput').value.toLowerCase();
  const container    = document.getElementById('receiptsList');

  let filtered = allReceipts.filter(r => {
    const matchStatus = !statusFilter || r.status === statusFilter;
    const matchSearch = !search ||
      (r.vendorName || '').toLowerCase().includes(search) ||
      r.amount.toString().includes(search);
    return matchStatus && matchSearch;
  });

  if (!filtered.length) {
    container.innerHTML = '<div class="empty-state"><div class="icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11L2 12v6a2 2 0 002 2h16a2 2 0 002-2v-6l-3.45-6.89A2 2 0 0016.76 4H7.24a2 2 0 00-1.79 1.11z"/></svg></div><p>Fiş bulunamadı</p></div>';
    return;
  }
  container.innerHTML = filtered.map(r => receiptRowHTML(r)).join('');
  attachReceiptClickHandlers(container, filtered);
}

document.getElementById('statusFilter').addEventListener('change', renderReceipts);
document.getElementById('searchInput').addEventListener('input', renderReceipts);

// ══════════════════════════════════════════════════════════════
// SECTION: HIGH RISK
// ══════════════════════════════════════════════════════════════
async function loadHighRisk(minScore = 60) {
  const container = document.getElementById('highRiskList');
  container.innerHTML = `
    <div class="skeleton-row" style="height:64px;border-radius:12px;background:var(--bg-card);margin-bottom:8px;animation:pulse 1.5s infinite"></div>
    <div class="skeleton-row" style="height:64px;border-radius:12px;background:var(--bg-card);margin-bottom:8px;animation:pulse 1.5s infinite"></div>
    <div class="skeleton-row" style="height:64px;border-radius:12px;background:var(--bg-card);animation:pulse 1.5s infinite"></div>
  `;

  let receipts;
  try {
    receipts = await apiFetch(`/api/admin/receipts/high-risk?minScore=${minScore}`);
  } catch (e) {
    console.error(e);
    receipts = [];
  }

  if (!receipts.length) {
    container.innerHTML = '<div class="empty-state"><div class="icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg></div><p>Bu eşiğin üzerinde riskli fiş yok</p></div>';
    return;
  }
  container.innerHTML = receipts.map(r => receiptRowHTML(r)).join('');
  attachReceiptClickHandlers(container, receipts);
}

const rangeInput    = document.getElementById('minScoreRange');
const rangeDisplay  = document.getElementById('minScoreDisplay');
rangeInput.addEventListener('input', () => { rangeDisplay.textContent = rangeInput.value; });
document.getElementById('refreshRisk').addEventListener('click', () => {
  loadHighRisk(parseInt(rangeInput.value));
});

// ══════════════════════════════════════════════════════════════
// SECTION: BUDGETS
// ══════════════════════════════════════════════════════════════
document.getElementById('budgetForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const msgEl = document.getElementById('budgetMsg');
  msgEl.style.display = 'none';

  const body = {
    departmentId: document.getElementById('budgetDeptId').value,
    year:  parseInt(document.getElementById('budgetYear').value),
    month: parseInt(document.getElementById('budgetMonth').value),
    limitAmount: parseFloat(document.getElementById('budgetLimit').value),
    currency: 'TRY',
  };

  try {
    await apiFetch('/api/admin/budgets', { method: 'PUT', body: JSON.stringify(body) });
    msgEl.className = 'budget-msg success';
    msgEl.textContent = 'Bütçe limiti kaydedildi!';
  } catch (e) {
    console.error(e);
    msgEl.className = 'budget-msg error';
    msgEl.textContent = 'Bütçe limiti kaydedilemedi: ' + e.message;
  }
  msgEl.style.display = 'block';
  setTimeout(() => { msgEl.style.display = 'none'; }, 4000);
});

document.getElementById('queryBudgetBtn').addEventListener('click', async () => {
  const deptId = document.getElementById('queryDeptId').value;
  const year   = document.getElementById('queryYear').value;
  const month  = document.getElementById('queryMonth').value;
  const resEl  = document.getElementById('budgetResult');

  if (!deptId) { showToast('Departman ID giriniz', 'error'); return; }

  try {
    const data = await apiFetch(`/api/admin/budgets/${deptId}/${year}/${month}`);
    renderBudgetResult(resEl, data);
  } catch (e) {
    console.error(e);
    resEl.innerHTML = '<div class="budget-msg error">Sorgu başarısız</div>';
  }
});

function renderBudgetResult(el, data) {
  const pct = Math.min(data.usagePercent, 100);
  const isDanger = data.isExceeded || pct >= 85;
  const deptName = escapeHTML(data.departmentName);
  
  el.innerHTML = `
    <div class="budget-result-card">
      <h4>${deptName}</h4>
      <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:.5rem;margin:.75rem 0;font-size:.85rem">
        <div><div style="color:var(--text2)">Limit</div><strong>${formatCurrency(data.limitAmount)}</strong></div>
        <div><div style="color:var(--text2)">Harcanan</div><strong style="color:${isDanger?'var(--red)':'var(--text)'}">${formatCurrency(data.spentAmount)}</strong></div>
        <div><div style="color:var(--text2)">Kalan</div><strong style="color:var(--green)">${formatCurrency(data.remainingAmount)}</strong></div>
      </div>
      <div class="progress-bar">
        <div class="progress-fill ${isDanger?'danger':''}" style="width:${pct}%"></div>
      </div>
      <div style="display:flex;justify-content:space-between;font-size:.78rem;color:var(--text2);margin-top:.25rem">
        <span>Kullanım: %${data.usagePercent.toFixed(1)}</span>
        ${data.isExceeded ? '<span style="color:var(--red);font-weight:600">BÜTÇE AŞILDI</span>' : ''}
      </div>
    </div>
  `;
}

// ══════════════════════════════════════════════════════════════
// SECTION: ANALYTICS
// ══════════════════════════════════════════════════════════════
let histInst = null, catInst = null;

async function loadAnalytics() {
  let analyticsData;
  try {
    analyticsData = await apiFetch('/api/dashboard/analytics');
  } catch (e) {
    console.error("Analytics fetch failed:", e);
    return;
  }

  const riskDist = analyticsData.riskDistribution || {};
  const catDist = analyticsData.categoryDistribution || {};

  // Risk Histogram
  const histLabels = ['0-10','10-20','20-30','30-50','50-70','70-100'];
  const buckets = histLabels.map(label => riskDist[label] || 0);
  const histColors = histLabels.map(l => {
    if (l === '70-100' || l === '50-70') return '#ef4444';
    if (l === '30-50' || l === '20-30') return '#f59e0b';
    return '#10b981';
  });

  if (histInst) histInst.destroy();
  histInst = new Chart(document.getElementById('riskHistogram').getContext('2d'), {
    type: 'bar',
    data: {
      labels: histLabels,
      datasets: [{ label: 'Fiş Sayısı', data: buckets, backgroundColor: histColors, borderRadius: 4 }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color:'#8b9cc8' } },
        y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color:'#8b9cc8', stepSize: 1 } },
      },
    },
  });

  // Category Pie
  if (catInst) catInst.destroy();
  catInst = new Chart(document.getElementById('categoryChart').getContext('2d'), {
    type: 'pie',
    data: {
      labels: Object.keys(catDist).map(c => CAT_LABELS[c] || c),
      datasets: [{ data: Object.values(catDist), backgroundColor: ['#6366f1','#10b981','#f59e0b','#ef4444','#a855f7','#3b82f6'], borderWidth: 2, borderColor: '#111827' }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { position: 'bottom', labels: { color:'#8b9cc8', font:{size:11}, padding: 10 } } },
    },
  });

  // Fraud Summary (Approximate from buckets or we could fetch stats, using simple calculation here)
  const highRisk = (riskDist['70-100']||0) + (riskDist['50-70']||0);
  const medRisk  = (riskDist['30-50']||0) + (riskDist['20-30']||0);
  const lowRisk  = (riskDist['10-20']||0) + (riskDist['0-10']||0);

  document.getElementById('fraudSummary').innerHTML = `
    <div class="fraud-stat"><div class="fraud-stat-value" style="color:var(--red)">${highRisk}</div><div class="fraud-stat-label">Yüksek Riskli (≥50)</div></div>
    <div class="fraud-stat"><div class="fraud-stat-value" style="color:var(--amber)">${medRisk}</div><div class="fraud-stat-label">Orta Riskli (20-50)</div></div>
    <div class="fraud-stat"><div class="fraud-stat-value" style="color:var(--green)">${lowRisk}</div><div class="fraud-stat-label">Düşük Riskli (<20)</div></div>
  `;
}

// ══════════════════════════════════════════════════════════════
// RECEIPT ROW & MODAL
// ══════════════════════════════════════════════════════════════
const CAT_LABELS = {
  food: 'Yemek', transport: 'Ulaşım', accommodation: 'Konaklama',
  fuel: 'Yakıt', office: 'Ofis', entertainment: 'Eğlence', other: 'Diğer',
};
const STATUS_TR = {
  Pending: 'Bekliyor', AiProcessing: 'AI İşliyor',
  Approved: 'Onaylı', Rejected: 'Reddedildi', Flagged: 'Bayraklı',
};

function receiptRowHTML(r) {
  const riskClass = r.riskLevel === 'High' ? 'high-risk' : r.riskLevel === 'Medium' ? 'medium-risk' : 'low-risk';
  const scoreClass = !r.fraudScore ? '' : r.fraudScore >= 60 ? 'score-high' : r.fraudScore >= 30 ? 'score-medium' : 'score-low';
  const safeVendor = escapeHTML(r.vendorName || 'Bilinmiyor');
  const safeCategory = escapeHTML(CAT_LABELS[r.category] || r.category || '—');
  
  return `
    <div class="receipt-row ${riskClass}" data-id="${escapeHTML(r.id)}">
      <div>
        <div class="vendor-name">${safeVendor}</div>
        <div class="receipt-date">${formatDate(r.receiptDate)} · ${formatDate(r.submittedAt, true)}</div>
      </div>
      <div class="receipt-category">${safeCategory}</div>
      <div class="receipt-amount">${formatCurrency(r.amount)}</div>
      <span class="status-badge status-${escapeHTML(r.status)}">${escapeHTML(STATUS_TR[r.status] || r.status)}</span>
      <div class="fraud-score ${scoreClass}">${r.fraudScore != null ? r.fraudScore : '—'}</div>
    </div>
  `;
}

function attachReceiptClickHandlers(container, receipts) {
  container.querySelectorAll('.receipt-row').forEach(row => {
    row.addEventListener('click', () => {
      const r = receipts.find(x => x.id === row.dataset.id);
      if (r) openReceiptModal(r);
    });
  });
}

// ── MODAL ──────────────────────────────────────────────────────
let modalReceipt = null;

function openReceiptModal(r) {
  modalReceipt = r;
  const reasons = parseReasons(r.fraudReasons);

  const safeVendor = escapeHTML(r.vendorName || '—');
  const safeCategory = escapeHTML(CAT_LABELS[r.category] || r.category);
  const safeStatus = escapeHTML(STATUS_TR[r.status] || r.status);
  const rawStatus = escapeHTML(r.status);

  document.getElementById('modalBody').innerHTML = `
    <div class="detail-grid">
      <div class="detail-item"><label>Satıcı</label><div class="val">${safeVendor}</div></div>
      <div class="detail-item"><label>Kategori</label><div class="val">${safeCategory}</div></div>
      <div class="detail-item"><label>Tutar</label><div class="val" style="font-size:1.1rem">${formatCurrency(r.amount)}</div></div>
      <div class="detail-item"><label>Fiş Tarihi</label><div class="val">${formatDate(r.receiptDate)}</div></div>
      <div class="detail-item"><label>Durum</label><div class="val"><span class="status-badge status-${rawStatus}">${safeStatus}</span></div></div>
      <div class="detail-item"><label>Fraud Skoru</label>
        <div class="val fraud-score ${r.fraudScore >= 60 ? 'score-high' : r.fraudScore >= 30 ? 'score-medium' : 'score-low'}" style="font-size:1.4rem">
          ${r.fraudScore != null ? escapeHTML(r.fraudScore) + '/100' : 'Bekleniyor...'}
        </div>
      </div>
    </div>
    ${reasons.length ? `
    <div class="fraud-reasons-list">
      <h4>Kural Kontrol Sonuçları</h4>
      ${reasons.map(rule => `
        <div class="reason-item ${rule.passed ? 'pass' : 'fail'}">
          <span class="reason-icon">${rule.passed ? '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><path d="M22 4L12 14.01l-3-3"/></svg>' : '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2.5" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><path d="M15 9l-6 6M9 9l6 6"/></svg>'}</span>
          <span>${escapeHTML(rule.message || rule.rule)}</span>
        </div>
      `).join('')}
    </div>` : ''}
  `;

  const actions = document.getElementById('modalActions');
  const canAct = r.status !== 'Approved' && r.status !== 'Rejected';
  actions.innerHTML = canAct ? `
    <button class="modal-btn-approve" id="approveBtn">Onayla</button>
    <button class="modal-btn-reject"  id="rejectBtn">Reddet</button>
  ` : `<span style="color:var(--text2);font-size:.85rem">Bu fiş için işlem yapılamaz (${safeStatus})</span>`;

  if (canAct) {
    document.getElementById('approveBtn').addEventListener('click', () => actionReceipt(r.id, 'approve'));
    document.getElementById('rejectBtn').addEventListener('click',  () => actionReceipt(r.id, 'reject'));
  }

  document.getElementById('receiptModal').style.display = 'flex';
}

async function actionReceipt(id, action) {
  document.getElementById('receiptModal').style.display = 'none';
  try {
    if (action === 'approve') {
      await apiFetch(`/api/receipts/${id}/approve`, { method: 'POST', body: '{}' });
      showToast('Fiş onaylandı');
      loadSection(window.currentSection || 'overview');
    } else {
      document.getElementById('rejectModal').style.display = 'flex';
      document.getElementById('rejectReasonText').value = '';
      
      const confirmBtn = document.getElementById('confirmRejectBtn');
      const newBtn = confirmBtn.cloneNode(true);
      confirmBtn.parentNode.replaceChild(newBtn, confirmBtn);
      
      newBtn.addEventListener('click', async () => {
        const reason = document.getElementById('rejectReasonText').value.trim() || 'Manuel red';
        document.getElementById('rejectModal').style.display = 'none';
        
        try {
          await apiFetch(`/api/receipts/${id}/reject`, { method: 'POST', body: JSON.stringify({ reason }) });
          showToast('Fiş reddedildi');
          loadSection(window.currentSection || 'overview');
        } catch (e) {
          console.error(e);
          showToast('İşlem başarısız', 'error');
        }
      });
    }
  } catch (e) {
    console.error(e);
    showToast('İşlem başarısız', 'error');
  }
}

document.getElementById('modalClose').addEventListener('click', () => {
  document.getElementById('receiptModal').style.display = 'none';
});
document.getElementById('receiptModal').addEventListener('click', (e) => {
  if (e.target === document.getElementById('receiptModal')) {
    document.getElementById('receiptModal').style.display = 'none';
  }
});

// ── HELPERS ────────────────────────────────────────────────────
function formatCurrency(n) {
  if (n == null) return '—';
  return '₺' + Number(n).toLocaleString('tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function formatDate(d, withTime = false) {
  if (!d) return '—';
  try {
    const dt = new Date(d);
    if (withTime) return dt.toLocaleString('tr-TR', { day:'2-digit', month:'2-digit', year:'numeric', hour:'2-digit', minute:'2-digit' });
    return dt.toLocaleDateString('tr-TR', { day:'2-digit', month:'2-digit', year:'numeric' });
  } catch { return d; }
}

function parseReasons(json) {
  try {
    const arr = JSON.parse(json || '[]');
    return Array.isArray(arr) ? arr : [];
  } catch { return []; }
}

// ══════════════════════════════════════════════════════════════
// SECTION: UPLOAD RECEIPT
// ══════════════════════════════════════════════════════════════
const submittedReceipts = [];

// ── DROP ZONE ──────────────────────────────────────────────────
const dropZone      = document.getElementById('dropZone');
const fileInput      = document.getElementById('fileInput');
const uploadPreview  = document.getElementById('uploadPreview');
const previewImg     = document.getElementById('previewImg');
const ocrStatus      = document.getElementById('ocrStatus');
const ocrResult      = document.getElementById('ocrResult');
const previewRemove  = document.getElementById('previewRemove');

if (dropZone) {
  dropZone.addEventListener('click', () => fileInput.click());
  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('drag-over');
  });
  dropZone.addEventListener('dragleave', () => dropZone.classList.remove('drag-over'));
  dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('drag-over');
    if (e.dataTransfer.files.length) handleFileUpload(e.dataTransfer.files[0]);
  });
  fileInput.addEventListener('change', () => {
    if (fileInput.files.length) handleFileUpload(fileInput.files[0]);
  });
}

if (previewRemove) {
  previewRemove.addEventListener('click', () => {
    uploadPreview.style.display = 'none';
    ocrResult.style.display = 'none';
    dropZone.style.display = 'flex';
    fileInput.value = '';
  });
}

// ── OPENAI GPT-4 VISION — Gerçek fiş OCR ───────────────────────
const OPENAI_API_KEY = ''; // Güvenlik nedeniyle kaldırıldı. Production'da backend üzerinden çağrılmalıdır.

async function analyzeReceiptWithAI(file) {
  const toBase64 = (f) => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result.split(',')[1]);
    reader.onerror = reject;
    reader.readAsDataURL(f);
  });

  const base64Image = await toBase64(file);
  const mimeType = file.type || 'image/jpeg';

  const prompt = `Bu bir fiş veya fatura görüntüsüdür. Aşağıdaki bilgileri JSON formatında çıkar:
{
  "vendorName": "İşyeri/mağaza adı (string)",
  "receiptDate": "Tarih YYYY-MM-DD formatında (string)",
  "amount": toplam ödenecek tutar (number),
  "taxAmount": KDV tutarı (number, yoksa 0),
  "category": "food, transport, fuel, accommodation, office, entertainment, other seçeneklerinden biri"
}
Sadece JSON döndür, başka açıklama ekleme. Türkçe fişlerde 'Ödenecek Toplam', 'Net Toplam' gibi alanları tutar olarak kullan. KDV bulamazsan 0 yaz. Tarih bulamazsan bugünün tarihini kullan.`;

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${OPENAI_API_KEY}`
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      max_tokens: 300,
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: `data:${mimeType};base64,${base64Image}`, detail: 'high' } }
        ]
      }]
    })
  });

  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.error?.message || 'OpenAI API hatası');
  }

  const data = await res.json();
  const content = data.choices[0].message.content.trim();
  const jsonStr = content.replace(/```json|```/g, '').trim();
  return JSON.parse(jsonStr);
}

async function handleFileUpload(file) {
  if (file.size > 10 * 1024 * 1024) {
    showToast('Dosya 10MB\'den büyük olamaz', 'error');
    return;
  }

  // Show preview
  dropZone.style.display = 'none';
  uploadPreview.style.display = 'block';
  ocrStatus.style.display = 'flex';
  ocrResult.style.display = 'none';

  const reader = new FileReader();
  reader.onload = (e) => { previewImg.src = e.target.result; };
  reader.readAsDataURL(file);

  // ── GPT-4 Vision ile Gerçek OCR ──────────────────────────────
  const statusEl = ocrStatus.querySelector('span');
  const stages = [
    'Görüntü yükleniyor...',
    'GPT-4 Vision\'a gönderiliyor...',
    'Fiş bilgileri okunuyor...',
    'Kategori belirleniyor...',
  ];

  let stageIdx = 0;
  if (statusEl) statusEl.textContent = stages[0];
  const stageInterval = setInterval(() => {
    if (stageIdx < stages.length - 1) {
      stageIdx++;
      if (statusEl) statusEl.textContent = stages[stageIdx];
    }
  }, 1400);

  try {
    const result = await analyzeReceiptWithAI(file);
    clearInterval(stageInterval);

    document.getElementById('ocrVendor').value = result.vendorName || '';
    document.getElementById('ocrDate').value   = result.receiptDate || new Date().toISOString().split('T')[0];
    document.getElementById('ocrAmount').value = result.amount || 0;
    document.getElementById('ocrTax').value    = result.taxAmount || 0;

    const catSelect = document.getElementById('ocrCategory');
    if (catSelect && result.category) catSelect.value = result.category;

    ocrStatus.style.display = 'none';
    ocrResult.style.display = 'block';
    showToast('✅ AI analizi tamamlandı — fiş bilgileri otomatik çıkarıldı!');
  } catch (aiErr) {
    clearInterval(stageInterval);
    console.error('GPT-4 Vision hatası:', aiErr);
    showToast('AI analizi başarısız: ' + aiErr.message, 'error');
    ocrStatus.style.display = 'none';
    ocrResult.style.display = 'block';

  }
}

// ── SUBMIT OCR RECEIPT ─────────────────────────────────────────
const submitOcrBtn = document.getElementById('submitOcrReceipt');
if (submitOcrBtn) {
  submitOcrBtn.addEventListener('click', async () => {
    const payload = {
      vendorName: document.getElementById('ocrVendor').value,
      category: document.getElementById('ocrCategory')?.value || 'other',
      amount: parseFloat(document.getElementById('ocrAmount').value),
      receiptDate: document.getElementById('ocrDate').value,
      method: 'OCR'
    };

    submitOcrBtn.textContent = 'Gönderiliyor...';
    submitOcrBtn.disabled = true;

    try {
      const receipt = await apiFetch('/api/receipts', { method: 'POST', body: JSON.stringify(payload) });
      
      submittedReceipts.push(receipt);
      renderSubmittedReceipts();

      showToast('Fiş başarıyla yüklendi! AI analizine gönderildi.');
      
      // Reset
      uploadPreview.style.display = 'none';
      ocrResult.style.display = 'none';
      dropZone.style.display = 'flex';
      fileInput.value = '';
    } catch (e) {
      console.error(e);
      showToast('Fiş yüklenemedi', 'error');
    } finally {
      submitOcrBtn.textContent = 'Fişi Gönder';
      submitOcrBtn.disabled = false;
    }
  });
}

// ── MANUAL RECEIPT FORM ────────────────────────────────────────
const manualForm = document.getElementById('manualReceiptForm');
if (manualForm) {
  // Set default date to today
  const dateField = document.getElementById('manualDate');
  if (dateField) dateField.value = new Date().toISOString().split('T')[0];

  manualForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = document.getElementById('submitManualReceipt');

    const receipt = {
      id: 'r' + Date.now(),
      vendorName: document.getElementById('manualVendor').value,
      category: document.getElementById('manualCategory').value,
      amount: parseFloat(document.getElementById('manualAmount').value),
      receiptDate: document.getElementById('manualDate').value,
      status: 'AiProcessing',
      riskLevel: 'Pending',
      fraudScore: null,
      submittedAt: new Date().toISOString(),
      fraudReasons: null,
      method: 'Manuel',
      note: document.getElementById('manualNote').value || '',
    };

    btn.textContent = 'Gönderiliyor...';
    btn.disabled = true;

    try {
      const created = await apiFetch('/api/receipts', { method: 'POST', body: JSON.stringify(receipt) });
      submittedReceipts.push(created);
      renderSubmittedReceipts();

      showToast(`Fiş başarıyla gönderildi!`);
      manualForm.reset();
      if (dateField) dateField.value = new Date().toISOString().split('T')[0];
    } catch(e) {
      console.error(e);
      showToast('Fiş gönderilemedi', 'error');
    } finally {
      btn.textContent = 'Fişi Gönder';
      btn.disabled = false;
    }
  });
}

function renderSubmittedReceipts() {
  const container = document.getElementById('submittedReceipts');
  const list      = document.getElementById('submittedList');
  if (!container || !list) return;

  container.style.display = 'block';
  list.innerHTML = submittedReceipts.map(r => {
    const scoreClass = r.fraudScore >= 60 ? 'score-high' : r.fraudScore >= 30 ? 'score-medium' : 'score-low';
    const safeVendor = escapeHTML(r.vendorName);
    const safeMethod = escapeHTML(r.method);
    const safeStatus = escapeHTML(STATUS_TR[r.status] || r.status);
    const rawStatus  = escapeHTML(r.status);
    
    return `
      <div class="submitted-row">
        <div class="submitted-info">
          <strong>${safeVendor}</strong>
          <span class="submitted-meta">${safeMethod} · ${formatDate(r.receiptDate)} · ${formatCurrency(r.amount)}</span>
        </div>
        <div class="submitted-score ${scoreClass}">${r.fraudScore != null ? r.fraudScore + '/100' : '—'}</div>
        <span class="status-badge status-${rawStatus}">${safeStatus}</span>
      </div>
    `;
  }).reverse().join('');
}
