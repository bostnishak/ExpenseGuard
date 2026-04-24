/**
 * ExpenseGuard API Client
 * JWT Yönetimi, Token Yenileme (Refresh), ve Fetch Wrapper'ı içerir.
 */
class ApiClient {
    constructor(baseURL = 'http://localhost/api') {
        this.baseURL = baseURL;
    }

    // localStorage'dan mevcut session'ı al
    getSession() {
        const raw = localStorage.getItem('eg_session');
        if (!raw) return null;
        try {
            return JSON.parse(raw);
        } catch {
            return null;
        }
    }

    // Session'ı güncelle
    updateSession(sessionData) {
        localStorage.setItem('eg_session', JSON.stringify(sessionData));
    }

    // Wrapper: API'ye istek atar, 401 alırsa yenilemeyi dener
    async fetch(endpoint, options = {}) {
        let session = this.getSession();

        const headers = {
            'Content-Type': 'application/json',
            ...(options.headers || {})
        };

        if (session && session.token) {
            headers['Authorization'] = `Bearer ${session.token}`;
        }

        const url = `${this.baseURL}${endpoint}`;
        let response = await window.fetch(url, { ...options, headers });

        if (response.status === 401 && session && session.refreshToken) {
            // Token süresi dolmuş, yenilemeyi dene
            const refreshed = await this.refreshToken(session.refreshToken);
            if (refreshed) {
                // Yeni token ile asıl isteği tekrarla
                headers['Authorization'] = `Bearer ${refreshed.token}`;
                response = await window.fetch(url, { ...options, headers });
            } else {
                // Refresh de patladı, çıkış yap
                this.logout();
                throw new Error("Oturum süresi doldu, lütfen tekrar giriş yapın.");
            }
        }

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.error || `API Hatası: ${response.status}`);
        }

        return response.json();
    }

    async refreshToken(refreshToken) {
        try {
            const res = await window.fetch(`${this.baseURL}/auth/refresh`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ refreshToken })
            });
            if (res.ok) {
                const data = await res.json();
                let session = this.getSession();
                session.token = data.token;
                session.refreshToken = data.refreshToken;
                this.updateSession(session);
                return data;
            }
            return null;
        } catch {
            return null;
        }
    }

    logout() {
        localStorage.removeItem('eg_session');
        window.location.href = 'login.html';
    }
}

// Global instance
window.egApi = new ApiClient();
