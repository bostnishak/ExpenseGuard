import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _domainController = TextEditingController(text: 'expenseguard.com');
  bool _isLoading = false;

  // ── Demo Hesaplar ──
  static const _demoAccounts = [
    {'email': 'admin@expenseguard.com', 'password': 'Test1234!', 'role': 'Sistem Admini', 'icon': '⚙️', 'color': 0xFFF59E0B},
    {'email': 'yonetici@expenseguard.com', 'password': 'Test1234!', 'role': 'Departman Yöneticisi', 'icon': '👔', 'color': 0xFF3B82F6},
    {'email': 'calisan@expenseguard.com', 'password': 'Test1234!', 'role': 'Çalışan', 'icon': '👤', 'color': 0xFF34D399},
    {'email': 'finans@expenseguard.com', 'password': 'Test1234!', 'role': 'Finans Uzmanı', 'icon': '💼', 'color': 0xFFA78BFA},
  ];

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.login(
        _emailController.text,
        _passwordController.text,
        _domainController.text,
      );

      if (response.isSuccess) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        _showError(response.error ?? 'Giriş başarısız. Bilgilerinizi kontrol edin.');
      }
    } catch (e) {
      // API offline — Demo mod ile giriş dene
      final email = _emailController.text.trim().toLowerCase();
      final pw = _passwordController.text;
      final demo = _demoAccounts.cast<Map<String, dynamic>>().firstWhere(
        (d) => d['email'] == email && d['password'] == pw,
        orElse: () => {},
      );

      if (demo.isNotEmpty) {
        // Demo modda session kaydet
        await ApiService.saveDemoSession(
          email: email,
          role: demo['role'] as String,
          domain: _domainController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Demo modda giriş yapıldı (API offline)'),
          backgroundColor: Color(0xFF34D399),
        ));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        _showError('Sunucu bağlantı hatası. Demo hesap bilgileri de eşleşmiyor.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillDemoAccount(Map<String, dynamic> account) {
    setState(() {
      _emailController.text = account['email'] as String;
      _passwordController.text = account['password'] as String;
      _domainController.text = 'expenseguard.com';
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A06),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.3),
                radius: 1.5,
                colors: [
                  Color(0x1FF59E0B),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // ── LOGIN CARD ──
                  Container(
                    constraints: const BoxConstraints(maxWidth: 430),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1109),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x2EF59E0B)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x14F59E0B), blurRadius: 80, spreadRadius: 0),
                        BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top accent line
                        Container(
                          height: 3,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                            gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFFB7185)]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(11),
                                      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
                                      boxShadow: const [BoxShadow(color: Color(0x33F59E0B), blurRadius: 18, offset: Offset(0, 4))],
                                    ),
                                    child: const Center(child: Text('EG', style: TextStyle(color: Color(0xFF0F0A06), fontWeight: FontWeight.w800, fontSize: 16))),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text('ExpenseGuard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                                ],
                              ),
                              const SizedBox(height: 32),
                              const Text('Hoş Geldiniz', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5), textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              const Text('Sisteme giriş yapmak için bilgilerinizi girin.', style: TextStyle(color: Color(0xFFC4A882), fontSize: 14), textAlign: TextAlign.center),
                              const SizedBox(height: 32),

                              _buildTextField('Şirket Domain', Icons.business, _domainController, false),
                              const SizedBox(height: 16),
                              _buildTextField('E-posta', Icons.email, _emailController, false, TextInputType.emailAddress),
                              const SizedBox(height: 16),
                              _buildTextField('Şifre', Icons.lock, _passwordController, true),
                              const SizedBox(height: 32),

                              // Login Button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
                                  boxShadow: const [BoxShadow(color: Color(0x33F59E0B), blurRadius: 22, offset: Offset(0, 4))],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0F0A06), strokeWidth: 2.5))
                                      : const Text('Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F0A06))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── DEMO ACCOUNTS ──
                  Container(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 20),
                            SizedBox(width: 8),
                            Text('Demo Hesaplar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFFDF4E7))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Kartlara dokunarak demo hesap bilgilerini otomatik doldurun.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF7A6347)),
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
        ],
      ),
    );
  }

  Widget _buildDemoCard(Map<String, dynamic> account) {
    final color = Color(account['color'] as int);
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
              child: Center(child: Text(account['icon'] as String, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account['role'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFFDF4E7))),
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

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, bool obscureText, [TextInputType? keyboardType]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFC4A882), letterSpacing: 0.3)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFFFDF4E7), fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0x08F59E0B),
            prefixIcon: Icon(icon, color: const Color(0xFFC4A882), size: 18),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x2EF59E0B))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x2EF59E0B))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
          ),
        ),
      ],
    );
  }
}
