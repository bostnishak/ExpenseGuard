import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'camera_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ── Demo OCR senaryo verileri ─────────────────────────────────
class _DemoOcrScenario {
  final String vendorName;
  final double amount;
  final double taxAmount;
  final String category;
  final int dayOffset;
  const _DemoOcrScenario({
    required this.vendorName,
    required this.amount,
    required this.taxAmount,
    required this.category,
    this.dayOffset = 0,
  });
}

const _demoScenarios = [
  _DemoOcrScenario(vendorName: 'Migros Ataşehir AVM',    amount: 347.85, taxAmount: 62.61,  category: 'food'),
  _DemoOcrScenario(vendorName: 'Shell Kadıköy İstasyonu', amount: 1120.00, taxAmount: 201.60, category: 'fuel', dayOffset: -1),
  _DemoOcrScenario(vendorName: 'Hilton Istanbul Bomonti', amount: 3750.00, taxAmount: 675.00, category: 'accommodation', dayOffset: -2),
  _DemoOcrScenario(vendorName: 'Uber Türkiye',            amount: 214.50, taxAmount: 38.61,  category: 'transport'),
  _DemoOcrScenario(vendorName: 'Starbucks Maslak',        amount: 189.00, taxAmount: 34.02,  category: 'food'),
  _DemoOcrScenario(vendorName: 'Teknosa Levent Park',     amount: 2890.00, taxAmount: 520.20, category: 'office', dayOffset: -1),
  _DemoOcrScenario(vendorName: 'Pegasus Havayolları',     amount: 1450.00, taxAmount: 261.00, category: 'transport', dayOffset: -3),
  _DemoOcrScenario(vendorName: 'Carrefour Maltepe',       amount: 523.40, taxAmount: 94.21,  category: 'food'),
  _DemoOcrScenario(vendorName: 'BP Petrol Ümraniye',      amount: 980.00, taxAmount: 176.40, category: 'fuel', dayOffset: -1),
  _DemoOcrScenario(vendorName: 'Yemeksepeti Kurumsal',    amount: 268.90, taxAmount: 48.40,  category: 'food'),
];

/// Fiş Yükleme Ekranı — Kamera, Galeri ve Dosya seçenekleri
class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({super.key});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _processingStage = '';
  String? _selectedImagePath;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Seçim yöntemleri ────────────────────────────────────────
  Future<void> _pickFromCamera() async {
    // Direkt kamera ekranına git (tam ekran kamera deneyimi)
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (image != null) {
        _processSelectedImage(image.path);
      }
    } catch (e) {
      _showError('Galeri açılamadı: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    // image_picker ile kamerayı kaynak olarak kullanmadan dosya seçimi
    // Android'de bu otomatik olarak dosya yöneticisini de gösterir
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (image != null) {
        _processSelectedImage(image.path);
      }
    } catch (e) {
      _showError('Dosya seçilemedi: $e');
    }
  }

  // ── Seçilen görüntüyü işle ─────────────────────────────────
  Future<void> _processSelectedImage(String imagePath) async {
    setState(() {
      _selectedImagePath = imagePath;
      _isProcessing = true;
      _processingStage = 'Hazırlanıyor...';
    });

    // ── DEMO MOD ──────────────────────────────────────────────
    if (await ApiService.isDemoMode()) {
      final stages = [
        'Görüntü ön işleniyor...',
        'OCR metin çıkarılıyor...',
        'AI fiş alanlarını analiz ediyor...',
        'Fraud risk skoru hesaplanıyor...',
      ];

      for (final stage in stages) {
        if (!mounted) return;
        setState(() => _processingStage = stage);
        await Future.delayed(Duration(milliseconds: 600 + Random().nextInt(500)));
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final scenario = _demoScenarios[Random().nextInt(_demoScenarios.length)];
      final receiptDate = DateTime.now().add(Duration(days: scenario.dayOffset));
      final fraudScore = Random().nextInt(40) + 5;

      _showOcrResultSheet(
        vendorName: scenario.vendorName,
        amount: scenario.amount,
        taxAmount: scenario.taxAmount,
        category: scenario.category,
        receiptDate: receiptDate,
        fraudScore: fraudScore,
        imagePath: imagePath,
      );
      return;
    }

    // ── GERÇEK API ────────────────────────────────────────────
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await ApiService.post('/api/receipts', {
        'imageBase64': base64Image,
        'method': 'OCR_MOBILE',
      });

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fiş başarıyla yüklendi ve AI analizine gönderildi!'),
            backgroundColor: AppTheme.statusApproved,
          ),
        );
        Navigator.of(context).pop();
      } else {
        _showError(response.error ?? 'Yükleme başarısız.');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Sunucu bağlantı hatası: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.statusRejected),
    );
  }

  // ── OCR Sonuç Bottom Sheet ─────────────────────────────────
  void _showOcrResultSheet({
    required String vendorName,
    required double amount,
    required double taxAmount,
    required String category,
    required DateTime receiptDate,
    required int fraudScore,
    required String imagePath,
  }) {
    final categoryLabels = {
      'food': 'Yemek', 'fuel': 'Yakıt', 'transport': 'Ulaşım',
      'accommodation': 'Konaklama', 'office': 'Ofis Malzemesi',
    };
    final riskColor = fraudScore >= 60
        ? AppTheme.statusRejected
        : fraudScore >= 30
            ? AppTheme.secondaryOrange
            : AppTheme.statusApproved;
    final riskLabel = fraudScore >= 60 ? 'Yüksek Risk' : fraudScore >= 30 ? 'Orta Risk' : 'Düşük Risk';
    final dateStr = '${receiptDate.day.toString().padLeft(2, '0')}.${receiptDate.month.toString().padLeft(2, '0')}.${receiptDate.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.primaryGold, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Tarama Tamamlandı', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Fiş bilgileri otomatik çıkarıldı', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Önizleme
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagePath), height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),

            // Sonuç alanları
            _resultRow('Satıcı', vendorName, Icons.store),
            _resultRow('Kategori', categoryLabels[category] ?? category, Icons.category),
            _resultRow('Tutar', '₺${amount.toStringAsFixed(2)}', Icons.payments),
            _resultRow('KDV', '₺${taxAmount.toStringAsFixed(2)}', Icons.receipt_long),
            _resultRow('Tarih', dateStr, Icons.calendar_today),
            const SizedBox(height: 12),

            // Fraud skoru
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: riskColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.shield, color: riskColor, size: 20),
                    const SizedBox(width: 8),
                    const Text('Fraud Risk Skoru', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                  ]),
                  Row(children: [
                    Text('$fraudScore/100', style: TextStyle(color: riskColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: riskColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text(riskLabel, style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Gönder
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fiş başarıyla kaydedildi ve onay akışına gönderildi!'),
                      backgroundColor: AppTheme.statusApproved,
                    ),
                  );
                  setState(() => _selectedImagePath = null);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text('Fişi Onayla ve Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold.withOpacity(0.7), size: 18),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceGlass,
        elevation: 0,
        title: const Text('Fiş Yükle'),
        centerTitle: true,
      ),
      body: _isProcessing ? _buildProcessingView() : _buildSelectionView(),
    );
  }

  // ── İşleme görünümü (AI analiz ediliyor) ───────────────────
  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seçilen resim önizlemesi
          if (_selectedImagePath != null)
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3), width: 2),
                boxShadow: AppTheme.glassShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(_selectedImagePath!),
                  height: 200,
                  width: 260,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Pulse animasyonlu AI ikonu
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.15),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGold.withOpacity(0.1 + _pulseController.value * 0.08),
                    border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.primaryGold, size: 36),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Text(
            _processingStage,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yapay zeka fiş görüntüsünü analiz ediyor',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: AppTheme.primaryGold,
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ana seçim görünümü ─────────────────────────────────────
  Widget _buildSelectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık açıklaması
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGold.withOpacity(0.08),
                  AppTheme.secondaryOrange.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.primaryGold, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'AI Destekli Fiş Tarama',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Fişin fotoğrafını çekin veya mevcut bir görseli seçin. Yapay zeka otomatik olarak satıcı, tutar, tarih ve KDV bilgilerini çıkaracak.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Yükleme seçenekleri başlığı
          const Text(
            'Yükleme Yöntemi Seçin',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // ── Kamera kartı ─────────────────────────────────────
          _buildOptionCard(
            icon: Icons.camera_alt_rounded,
            title: 'Kamera ile Çek',
            subtitle: 'Fişin fotoğrafını şimdi çekin',
            gradientColors: [const Color(0xFF6366f1), const Color(0xFF8b5cf6)],
            onTap: _pickFromCamera,
            badge: 'Önerilen',
          ),
          const SizedBox(height: 14),

          // ── Galeri kartı ─────────────────────────────────────
          _buildOptionCard(
            icon: Icons.photo_library_rounded,
            title: 'Galeriden Seç',
            subtitle: 'Daha önce çekilmiş fotoğraflardan seçin',
            gradientColors: [const Color(0xFF10b981), const Color(0xFF059669)],
            onTap: _pickFromGallery,
          ),
          const SizedBox(height: 14),

          // ── Dosya kartı ──────────────────────────────────────
          _buildOptionCard(
            icon: Icons.folder_open_rounded,
            title: 'Dosyalardan Seç',
            subtitle: 'İndirilenler, e-posta ekleri veya diğer dosyalar',
            gradientColors: [AppTheme.primaryGold, AppTheme.secondaryOrange],
            onTap: _pickFromFiles,
          ),
          const SizedBox(height: 32),

          // ── Desteklenen formatlar ────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.textMuted, size: 16),
                    SizedBox(width: 6),
                    Text('Desteklenen Formatlar', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['JPG', 'PNG', 'WEBP', 'HEIC', 'PDF'].map((fmt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
                      ),
                      child: Text(fmt, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Maksimum dosya boyutu: 10 MB',
                  style: TextStyle(color: AppTheme.textDarkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Seçenek kartı widget'ı ─────────────────────────────────
  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gradientColors[0].withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: gradientColors[0].withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // İkon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),

            // Metin
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: gradientColors[0].withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(badge, style: TextStyle(color: gradientColors[0], fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),

            // Ok ikonu
            Icon(Icons.chevron_right_rounded, color: gradientColors[0].withOpacity(0.6), size: 24),
          ],
        ),
      ),
    );
  }
}
