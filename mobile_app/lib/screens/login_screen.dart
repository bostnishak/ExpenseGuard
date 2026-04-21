import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  final String initialTab;
  const LoginScreen({super.key, this.initialTab = 'login'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _domainController = TextEditingController(text: 'expenseguard.com');
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const _demoAccounts = [
    {'email': 'admin@expenseguard.com', 'password': 'Test1234!', 'role': 'Sistem Admini', 'icon': Icons.shield_outlined, 'color': AppTheme.primaryGold},
    {'email': 'yonetici@expenseguard.com', 'password': 'Test1234!', 'role': 'Departman Yöneticisi', 'icon': Icons.work_outline, 'color': Colors.blue},
    {'email': 'calisan@expenseguard.com', 'password': 'Test1234!', 'role': 'Çalışan', 'icon': Icons.person_outline, 'color': AppTheme.statusApproved},
    {'email': 'finans@expenseguard.com', 'password': 'Test1234!', 'role': 'Finans & Denetim', 'icon': Icons.monetization_on_outlined, 'color': Colors.purpleAccent},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialTab == 'register' ? 1 : 0
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Lütfen e-posta ve şifrenizi girin.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.login(
        _emailController.text,
        _passwordController.text,
        _domainController.text,
      );

      if (response.isSuccess) {
        _navigateToMain();
      } else {
        _showError(response.error ?? 'Giriş başarısız. Bilgilerinizi kontrol edin.');
      }
    } catch (e) {
      // Offline fallback: Demo mode
      final email = _emailController.text.trim().toLowerCase();
      final pw = _passwordController.text;
      
      Map<String, dynamic>? demo;
      try {
        demo = _demoAccounts.cast<Map<String, dynamic>>().firstWhere(
          (d) => d['email'] == email && d['password'] == pw,
        );
      } catch (_) {}

      if (demo != null) {
        await ApiService.saveDemoSession(
          email: email,
          role: demo['role'] as String,
          domain: _domainController.text,
        );
        _showSuccess('Demo modda giriş yapıldı (API offline)');
        _navigateToMain();
      } else {
        _showError('Sunucu bağlantı hatası veya geçersiz demo hesabı.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (_) => false,
    );
  }

  void _fillDemoAccount(Map<String, dynamic> account) {
    setState(() {
      _tabController.animateTo(0); // Switch to login tab
      _emailController.text = account['email'] as String;
      _passwordController.text = account['password'] as String;
      _domainController.text = 'expenseguard.com';
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.statusRejected));
  }
  
  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.statusApproved));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ana Sayfaya Dön', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Background Glow
          Container(decoration: const BoxDecoration(gradient: AppTheme.bgGlow)),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  children: [
                    // Main Glass Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGlass,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
                        boxShadow: AppTheme.glassShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Custom TabBar
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppTheme.primaryGold.withOpacity(0.1))),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorColor: AppTheme.primaryGold,
                              indicatorWeight: 3,
                              labelColor: AppTheme.primaryGold,
                              unselectedLabelColor: AppTheme.textMuted,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              tabs: const [
                                Tab(text: 'Giriş Yap'),
                                Tab(text: 'Üye Ol'),
                              ],
                            ),
                          ),
                          
                          // TabBarView Content
                          SizedBox(
                            height: 380, // Fixed height for form area
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildLoginForm(),
                                _buildRegisterForm(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Demo Accounts Section
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: AppTheme.primaryGold, size: 20),
                              SizedBox(width: 8),
                              Text('Demo Hesaplar — Test Modu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Kartlara dokunarak demo hesap bilgilerini otomatik doldurun.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textDarkMuted),
                          ),
                          const SizedBox(height: 14),
                          ..._demoAccounts.map((account) => _buildDemoCard(account)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField('Şirket Domain', Icons.business, _domainController, false),
          const SizedBox(height: 16),
          _buildTextField('E-posta', Icons.email_outlined, _emailController, false, TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField('Şifre', Icons.lock_outline, _passwordController, _obscurePassword, null, true),
          
          const Spacer(),
          
          // Submit Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: AppTheme.primaryGradient,
              boxShadow: AppTheme.buttonGlow,
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.bgDark, strokeWidth: 2.5))
                  : const Text('Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.bgDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Demo Modu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yeni üyelik alımları sadece kurumsal satış temsilcilerimiz aracılığıyla yapılmaktadır. Lütfen info@expenseguard.com üzerinden iletişime geçin veya Demo Hesapları kullanın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _tabController.animateTo(0),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.5)),
            ),
            child: const Text('Giriş Ekranına Dön', style: TextStyle(color: AppTheme.primaryGold)),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, bool obscureText, [TextInputType? keyboardType, bool isPassword = false]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 0.3)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.primaryGold.withOpacity(0.05),
            prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ) : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryGold)),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoCard(Map<String, dynamic> account) {
    final color = account['color'] as Color;
    return GestureDetector(
      onTap: () => _fillDemoAccount(account),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF221509),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Center(child: Icon(account['icon'] as IconData, color: color, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account['role'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(account['email'] as String, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
