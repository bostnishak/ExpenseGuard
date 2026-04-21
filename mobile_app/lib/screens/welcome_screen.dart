import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isAnnual = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Background Glow Effect - Fixed at top
          Positioned(
            top: -200,
            left: -100,
            right: -100,
            height: 600,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Color(0x1FF59E0B),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 60),
                  _buildHeroSection(context),
                  const SizedBox(height: 60),
                  _buildHeroStats(),
                  const SizedBox(height: 80),
                  _buildFeaturesSection(),
                  const SizedBox(height: 80),
                  _buildRoiSection(),
                  const SizedBox(height: 80),
                  _buildHowItWorksSection(),
                  const SizedBox(height: 80),
                  _buildComparisonSection(),
                  const SizedBox(height: 80),
                  _buildTestimonialsSection(),
                  const SizedBox(height: 80),
                  _buildPricingSection(context),
                  const SizedBox(height: 80),
                  _buildFooterCta(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.buttonGlow,
          ),
          child: const Center(
            child: Text(
              'EG', 
              style: TextStyle(color: AppTheme.bgDark, fontWeight: FontWeight.w900, fontSize: 14)
            )
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'ExpenseGuard', 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: AppTheme.textPrimary)
        ),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      children: [
        // Hero Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Türkiye'nin İlk AI-Native Platformu",
                style: TextStyle(color: AppTheme.primaryGold, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Hero Title
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 34, 
              fontWeight: FontWeight.w900, 
              height: 1.2,
              letterSpacing: -1.0,
              color: AppTheme.textPrimary,
            ),
            children: [
              TextSpan(text: 'Kurumsal Giderleri\n'),
              TextSpan(
                text: 'Akıllıca Yönet,',
                style: TextStyle(color: AppTheme.primaryGold),
              ),
              TextSpan(text: '\nFraud\'u Tespit Et'),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Hero Subtitle
        const Text(
          "OCR ile fiş tarama, LLM destekli anomali tespiti, çok kiracılı güvenlik ve gerçek zamanlı bütçe kontrolü — hepsi tek uygulamada.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 15, height: 1.5),
        ),

        const SizedBox(height: 40),

        // Actions
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.buttonGlow,
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen(initialTab: 'register')),
              );
            },
            child: const Text(
              '14 Gün Ücretsiz Dene', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.bgDark)
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen(initialTab: 'login')),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              side: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, color: AppTheme.textPrimary, size: 20),
                SizedBox(width: 8),
                Text('Canlı Demo Dene', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('14', 'Gün', 'Ücretsiz Deneme'),
              _buildStatItem('94', '%', 'Fraud Doğruluğu'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('67', '%', 'Maliyet Azalması'),
              _buildStatItem('99.9', '%', 'SLA Hedefi'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String suffix, String label) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            Text(suffix, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textDarkMuted)),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Özellikler',
          style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gider Yönetiminde Yeni Dönem',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.2, letterSpacing: -0.5),
        ),
        const SizedBox(height: 24),
        
        _buildFeatureCard(
          icon: Icons.document_scanner_outlined,
          title: 'Yapay Zeka Destekli OCR',
          desc: 'Fiş ve faturalarınızı kameraya tutun, AI tüm bilgileri saniyeler içinde otomatik olarak formlara doldursun.',
          color: AppTheme.primaryGold,
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          icon: Icons.security_outlined,
          title: 'LLM ile Fraud Tespiti',
          desc: 'Politika dışı harcamaları, mükerrer fişleri ve sahte tutarları %99 doğrulukla tespit edin ve risk skorunu görün.',
          color: AppTheme.statusRejected,
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          icon: Icons.business_outlined,
          title: 'Çok Kiracılı Mimari',
          desc: 'Role-Based Access Control (RBAC) ile farklı departmanlar ve şirketler için izole edilmiş güvenli altyapı.',
          color: AppTheme.statusApproved,
        ),
      ],
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String desc, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildRoiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text('NEDEN EXPENSEGUARD?', style: TextStyle(color: AppTheme.primaryGold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.2),
            children: [
              TextSpan(text: 'Somut Sonuçlar,\n'),
              TextSpan(text: 'Ölçülebilir ', style: TextStyle(color: AppTheme.primaryGold)),
              TextSpan(text: 'ROI', style: TextStyle(color: AppTheme.accentRed)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sistemin ilk 6 ayda sunmayı hedeflediği ölçülebilir iyileşmeler. Pilot kurumlarımızdan geri bildirim almaya devam ediyoruz.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 32),

        _buildRoiCard('67', '%', 'Gider Süreç Maliyetinde Azalma', 'Manuel fiş işleme ve onay süreçleri ortadan kalkıyor.', Icons.attach_money),
        const SizedBox(height: 16),
        _buildRoiCard('94', '%', 'Fraud Tespit Doğruluğu', 'Yapay zeka şüpheli harcamaları anında yakalıyor.', Icons.search),
        const SizedBox(height: 16),
        _buildRoiCard('3', 'x', 'Daha Hızlı Onay Süreci', 'Otomatik kurallar ve AI ile onaylar saniyeler içinde.', Icons.bolt),
        const SizedBox(height: 16),
        _buildRoiCard('85', '%', 'Zaman Tasarrufu', 'Finans ekibinin fiş işleme süresinde dramatik düşüş.', Icons.access_time),
      ],
    );
  }

  Widget _buildRoiCard(String val, String suffix, String title, String desc, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryGold, size: 24),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(val, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              Text(suffix, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryGold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textDarkMuted, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nasıl Çalışır',
          style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          '3 Adımda Masraf Süreci',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.2, letterSpacing: -0.5),
        ),
        const SizedBox(height: 32),
        
        _buildStepItem('1', 'Fişi Çek', 'Mobil uygulamadan masraf belgesinin fotoğrafını çekin.'),
        _buildStepConnector(),
        _buildStepItem('2', 'AI Analiz Etsin', 'Yapay zeka verileri okur, sınıflandırır ve fraud kontrolü yapar.'),
        _buildStepConnector(),
        _buildStepItem('3', 'Onayla ve Aktar', 'Yöneticiler tek tuşla onaylar, veriler ERP/Muhasebe sisteminize akar.'),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Container(
      margin: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
      width: 2,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryGold, AppTheme.primaryGold.withOpacity(0.1)],
        ),
      ),
    );
  }

  Widget _buildStepItem(String number, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: AppTheme.surfaceGlass,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5), width: 2),
            boxShadow: [BoxShadow(color: AppTheme.primaryGold.withOpacity(0.2), blurRadius: 10)],
          ),
          child: Center(
            child: Text(number, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Neden Rakiplerden Farklıyız?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.2, letterSpacing: -0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          "ExpenseGuard'ı piyasadaki diğer çözümlerle karşılaştırın.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 32),
        // Overflow problemini çözmek için tabloyu yatay kaydırılabilir hale getirdik
        // ve tablo hücrelerinin içeriğini daha esnek kıldık.
        Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FixedColumnWidth(100),
                    2: FixedColumnWidth(100),
                    3: FixedColumnWidth(140),
                  },
                  children: [
                    _buildTableRow('ÖZELLİK', 'EXPENSIFY', 'SAP CONCUR', 'EXPENSEGUARD', isHeader: true),
                    _buildTableSpacer(),
                    _buildTableRow('AI Fraud Tespiti', 'X', 'Kısmi', '✓ LLM Tabanlı'),
                    _buildTableRow('OCR Fiş Tarama', '✓', '✓', '✓ AI Destekli'),
                    _buildTableRow('Multi-Tenant', 'X', '✓', '✓ TenantId Bazlı'),
                    _buildTableRow('Türkçe Arayüz', 'X', 'Kısmi', '✓ Tam Türkçe'),
                    _buildTableRow('KVKK Uyumu', 'X', 'Kısmi', '✓ Tam Uyumlu'),
                    _buildTableRow('Başlangıç Fiyatı', '\$10/kul', 'Teklif Al', '₺2.499/ay (50)'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableSpacer() {
    return const TableRow(
      children: [
        SizedBox(height: 16), SizedBox(height: 16), SizedBox(height: 16), SizedBox(height: 16),
      ]
    );
  }

  TableRow _buildTableRow(String feature, String col1, String col2, String col3, {bool isHeader = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 12),
          child: Text(feature, style: TextStyle(color: isHeader ? AppTheme.textMuted : AppTheme.textPrimary, fontWeight: isHeader ? FontWeight.bold : FontWeight.w600, fontSize: isHeader ? 12 : 13)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 12),
          child: Text(col1, style: TextStyle(color: isHeader ? AppTheme.textMuted : (col1 == 'X' ? AppTheme.textDarkMuted : AppTheme.statusApproved), fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: isHeader ? 12 : 13)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 12),
          child: Text(col2, style: TextStyle(color: isHeader ? AppTheme.textMuted : (col2 == 'Kısmi' ? AppTheme.primaryGold : (col2 == 'X' ? AppTheme.textDarkMuted : AppTheme.textPrimary)), fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: isHeader ? 12 : 13)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(col3, style: TextStyle(color: isHeader ? AppTheme.primaryGold : AppTheme.statusApproved, fontWeight: FontWeight.bold, fontSize: isHeader ? 12 : 13)),
        ),
      ],
    );
  }

  Widget _buildTestimonialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text('MÜŞTERİ YORUMLARI', style: TextStyle(color: AppTheme.primaryGold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.2),
            children: [
              TextSpan(text: 'Beta Kullanıcılarımızdan\n'),
              TextSpan(text: 'İlk İzlenimler', style: TextStyle(color: AppTheme.primaryGold)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 260,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTestimonialCard(
                'M.K.', 'CFO — Teknoloji Şirketi',
                '"ExpenseGuard\'ın AI fraud tespiti ilk ayda 340.000 TL\'lik şüpheli harcamayı yakaladı. Yatırımın geri dönüşü harika."'
              ),
              const SizedBox(width: 16),
              _buildTestimonialCard(
                'A.Y.', 'Finans Direktörü — Holding',
                '"2.400 çalışanımızın raporları tamamen dijital. OCR ve otomatik onay akışları ekibimizin verimliliğini 3 katına çıkardı."'
              ),
              const SizedBox(width: 16),
              _buildTestimonialCard(
                'C.D.', 'CTO — Girişim',
                '"Multi-tenant yapısı sayesinde 12 farklı şirketimizin giderlerini tek panelden yönetiyoruz. KVKK uyumlu altyapı bizi çok rahatlattı."'
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestimonialCard(String name, String title, String comment) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: AppTheme.primaryGold, size: 16),
              Icon(Icons.star, color: AppTheme.primaryGold, size: 16),
              Icon(Icons.star, color: AppTheme.primaryGold, size: 16),
              Icon(Icons.star, color: AppTheme.primaryGold, size: 16),
              Icon(Icons.star, color: AppTheme.primaryGold, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Text(comment, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryGold,
                child: Text(name.substring(0, 2), style: const TextStyle(color: AppTheme.bgDark, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)),
                    Text(title, style: const TextStyle(color: AppTheme.textDarkMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Fiyatlandırma',
          style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kurumunuza Uygun Planlar',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1.2, letterSpacing: -0.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        // Aylık / Yıllık Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Aylık', style: TextStyle(color: !_isAnnual ? AppTheme.textPrimary : AppTheme.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _isAnnual = !_isAnnual),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppTheme.primaryGold.withOpacity(0.2),
                  border: Border.all(color: AppTheme.primaryGold),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeIn,
                      left: _isAnnual ? 24 : 2,
                      top: 2,
                      child: Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Text('Yıllık', style: TextStyle(color: _isAnnual ? AppTheme.textPrimary : AppTheme.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5)),
                  ),
                  child: const Text('%20 İndirim', style: TextStyle(color: AppTheme.primaryGold, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Starter Plan
        _buildPricingCard(
          context: context,
          title: 'STARTER',
          price: _isAnnual ? '₺1.999' : '₺2.499',
          desc: 'Küçük işletmeler için ideal başlangıç',
          features: ['50 kullanıcıya kadar', '5.000 fiş/ay OCR', 'Temel AI Fraud Tespiti', '3 Departman', 'Web Dashboard'],
          isPopular: false,
        ),
        const SizedBox(height: 24),
        
        // Enterprise Plan Card
        _buildPricingCard(
          context: context,
          title: 'ENTERPRISE',
          price: _isAnnual ? '₺6.399' : '₺7.999',
          desc: 'Büyüyen şirketler için gelişmiş özellikler',
          features: ['500 kullanıcıya kadar', '50.000 fiş/ay OCR', 'Gelişmiş AI + LLM', 'Sınırsız Departman', 'Mobil + Web', 'Multi-Tenant İzolasyon'],
          isPopular: true,
        ),
        const SizedBox(height: 24),
        
        // Corporate Plan Card
        _buildPricingCard(
          context: context,
          title: 'CORPORATE',
          price: 'Özel',
          desc: 'Holding ve büyük kurumlar için çözüm',
          features: ['Sınırsız kullanıcı', 'Sınırsız OCR', 'Özel AI Modeli', 'On-Premise Kurulum', 'ERP Entegrasyonu', 'SLA Garantisi'],
          isPopular: false,
        ),
      ],
    );
  }

  Widget _buildPricingCard({
    required BuildContext context, 
    required String title, 
    required String price, 
    required String desc,
    required List<String> features,
    required bool isPopular
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isPopular ? AppTheme.primaryGold : AppTheme.primaryGold.withOpacity(0.2)),
        boxShadow: isPopular ? [BoxShadow(color: AppTheme.primaryGold.withOpacity(0.15), blurRadius: 40)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('En Popüler', style: TextStyle(color: AppTheme.bgDark, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, height: 1)),
              if (price != 'Özel')
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
                  child: Text(_isAnnual ? '/ay (Yıllık)' : '/ay', style: const TextStyle(color: AppTheme.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(desc, style: const TextStyle(color: AppTheme.textDarkMuted, fontSize: 13)),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          
          ...features.map((f) => _buildPricingFeature(f)),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: isPopular ? AppTheme.primaryGradient : null,
                border: !isPopular ? Border.all(color: AppTheme.primaryGold.withOpacity(0.5)) : null,
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen(initialTab: 'register')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? Colors.transparent : Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: Text(
                  price == 'Özel' ? 'Teklif Al' : 'Hemen Başla', 
                  style: TextStyle(color: isPopular ? AppTheme.bgDark : AppTheme.primaryGold, fontWeight: FontWeight.w800, fontSize: 16)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: AppTheme.primaryGold, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildFooterCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text(
            'Hemen Kontrolü Ele Alın',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Gider süreçlerinizi otomatikleştirin, suiistimalleri engelleyin ve şirketinize değer katın.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Container(
               decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.buttonGlow,
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen(initialTab: 'register')),
                  );
                },
                child: const Text('Hemen Başla', style: TextStyle(color: AppTheme.bgDark, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
