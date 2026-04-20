import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

/// Kullanıcı profil ve ayarlar ekranı.
/// Hesap bilgileri, güvenlik seçenekleri (tüm cihazlardan çıkış) ve uygulama ayarları.
/// Demo modda profil bilgileri secure storage'dan okunur.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  bool _isDemoMode = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _isDemoMode = await ApiService.isDemoMode();

    final response = await ApiService.getMe();
    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _userInfo  = response.data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await _showConfirmDialog(
      'Çıkış Yap',
      'Bu cihazdan çıkış yapmak istiyor musunuz?',
    );
    if (!confirm || !mounted) return;

    await ApiService.logout();
    _navigateToLogin();
  }

  Future<void> _logoutAll() async {
    final confirm = await _showConfirmDialog(
      'Tüm Cihazlardan Çıkış',
      'Tüm cihazlardaki aktif oturumlarınız sonlandırılacak. Devam etmek istiyor musunuz?',
      destructive: true,
    );
    if (!confirm || !mounted) return;

    await ApiService.logoutAll();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<bool> _showConfirmDialog(
    String title,
    String content, {
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1109),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0x2EF59E0B)),
            ),
            title: Text(title, style: const TextStyle(color: Color(0xFFFDF4E7), fontWeight: FontWeight.w800)),
            content: Text(content, style: const TextStyle(color: Color(0xFFC4A882))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal', style: TextStyle(color: Color(0xFF7A6347))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: destructive ? Colors.redAccent : const Color(0xFFF59E0B),
                ),
                child: Text(destructive ? 'Çıkış Yap' : 'Evet'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatRole(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'employee': return 'Çalışan';
      case 'manager':  return 'Departman Yöneticisi';
      case 'finance':  return 'Finans Uzmanı';
      case 'admin':    return 'Sistem Yöneticisi';
      default:         return role ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A06),
      appBar: AppBar(
        title: const Text('Profil & Ayarlar', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF1C1109),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Demo Mod Banner ──
                if (_isDemoMode) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Demo modda çalışıyorsunuz. API bağlantısı yok.',
                            style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Avatar & İsim ──
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: const [BoxShadow(color: Color(0x33F59E0B), blurRadius: 24)],
                        ),
                        child: const Icon(Icons.person, size: 40, color: Color(0xFF0F0A06)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userInfo?['fullName'] ?? _userInfo?['email'] ?? 'Kullanıcı',
                        style: const TextStyle(color: Color(0xFFFDF4E7), fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                        ),
                        child: Text(
                          _formatRole(_userInfo?['role']),
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Hesap Bilgileri ──
                _buildSection('Hesap Bilgileri', [
                  _buildInfoTile(Icons.email_outlined, 'E-posta', _userInfo?['email'] ?? '-'),
                  _buildInfoTile(Icons.business_outlined, 'Tenant ID',
                      _userInfo?['tenantId']?.toString().substring(0, 8) ?? '-'),
                  _buildInfoTile(Icons.badge_outlined, 'Departman ID',
                      _userInfo?['departmentId']?.toString().substring(0, 8) ?? 'Atanmamış'),
                ]),

                const SizedBox(height: 20),

                // ── Güvenlik ──
                _buildSection('Güvenlik', [
                  _buildActionTile(
                    icon: Icons.logout,
                    label: 'Bu Cihazdan Çıkış',
                    subtitle: 'Yalnızca bu oturumu sonlandır',
                    color: Colors.orangeAccent,
                    onTap: _logout,
                  ),
                  _buildActionTile(
                    icon: Icons.phonelink_erase,
                    label: 'Tüm Cihazlardan Çıkış',
                    subtitle: 'Tüm aktif oturumları sonlandır',
                    color: Colors.redAccent,
                    onTap: _logoutAll,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Hakkında ──
                _buildSection('Uygulama', [
                  _buildInfoTile(Icons.info_outline, 'Sürüm', 'ExpenseGuard Pro v1.0.0'),
                  _buildInfoTile(Icons.security, 'Güvenlik', _isDemoMode ? 'Demo Mod Aktif' : 'JWT + Refresh Token Aktif'),
                ]),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1109),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x2EF59E0B)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFC4A882), size: 20),
      title: Text(label, style: const TextStyle(color: Color(0xFFC4A882), fontSize: 12)),
      subtitle: Text(value, style: const TextStyle(color: Color(0xFFFDF4E7), fontSize: 14)),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFFC4A882), fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF7A6347)),
      onTap: onTap,
    );
  }
}
