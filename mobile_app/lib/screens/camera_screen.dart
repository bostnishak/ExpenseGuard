import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ── Demo OCR senaryo verileri (gerçekçi Türkiye fişleri) ──────
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

const _demoOcrScenarios = [
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

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isReady = false;
  bool _isUploading = false;
  String _processingStage = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(_cameras[0], ResolutionPreset.high);
        await _controller!.initialize();
        if (!mounted) return;
        setState(() => _isReady = true);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndUpload() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isUploading = true;
      _processingStage = 'Fotoğraf çekiliyor...';
    });

    try {
      final image = await _controller!.takePicture();

      // ── DEMO MOD: Gerçekçi AI/OCR simülasyonu ─────────────
      if (await ApiService.isDemoMode()) {
        await _simulateDemoOcr(image.path);
        return;
      }

      // ── GERÇEK API MODU ────────────────────────────────────
      await _uploadReceipt(image.path);
    } catch (e) {
      _showError('Fotoğraf çekilirken hata oluştu: $e');
      setState(() => _isUploading = false);
    }
  }

  /// Demo modda gerçekçi AI işleme simülasyonu
  Future<void> _simulateDemoOcr(String imagePath) async {
    final stages = [
      'Görüntü ön işleniyor...',
      'OCR metin çıkarılıyor...',
      'AI fiş alanlarını analiz ediyor...',
      'Fraud risk skoru hesaplanıyor...',
    ];

    for (final stage in stages) {
      if (!mounted) return;
      setState(() => _processingStage = stage);
      await Future.delayed(Duration(milliseconds: 700 + Random().nextInt(500)));
    }

    if (!mounted) return;

    // Rastgele senaryo seç
    final scenario = _demoOcrScenarios[Random().nextInt(_demoOcrScenarios.length)];
    final receiptDate = DateTime.now().add(Duration(days: scenario.dayOffset));
    final fraudScore = Random().nextInt(40) + 5; // 5-44 arası düşük-orta risk

    setState(() => _isUploading = false);

    // Sonuç dialog'unu göster
    if (!mounted) return;
    _showOcrResultDialog(
      vendorName: scenario.vendorName,
      amount: scenario.amount,
      taxAmount: scenario.taxAmount,
      category: scenario.category,
      receiptDate: receiptDate,
      fraudScore: fraudScore,
      imagePath: imagePath,
    );
  }

  /// OCR sonuç dialog'u — yatırımcı demosunda etkileyici görünüm
  void _showOcrResultDialog({
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
    final riskColor = fraudScore >= 60 ? Colors.red : fraudScore >= 30 ? Colors.orange : const Color(0xFF10b981);
    final riskLabel = fraudScore >= 60 ? 'Yüksek Risk' : fraudScore >= 30 ? 'Orta Risk' : 'Düşük Risk';
    final dateStr = '${receiptDate.day.toString().padLeft(2, '0')}.${receiptDate.month.toString().padLeft(2, '0')}.${receiptDate.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Tarama Tamamlandı', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Fiş bilgileri otomatik çıkarıldı', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Fiş önizleme küçük resim
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagePath), height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),

            // OCR Sonuç alanları
            _buildResultRow('Satıcı', vendorName, Icons.store),
            _buildResultRow('Kategori', categoryLabels[category] ?? category, Icons.category),
            _buildResultRow('Tutar', '₺${amount.toStringAsFixed(2)}', Icons.payments),
            _buildResultRow('KDV', '₺${taxAmount.toStringAsFixed(2)}', Icons.receipt_long),
            _buildResultRow('Tarih', dateStr, Icons.calendar_today),
            const SizedBox(height: 12),

            // Fraud Skoru
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
                  Row(
                    children: [
                      Icon(Icons.shield, color: riskColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Fraud Risk Skoru', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('$fraudScore/100', style: TextStyle(color: riskColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: riskColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(riskLabel, style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Gönder butonu
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fiş başarıyla kaydedildi ve onay akışına gönderildi!'),
                      backgroundColor: Color(0xFF10b981),
                    ),
                  );
                  Navigator.of(context).pop(); // Kamera ekranından çık
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
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

  Widget _buildResultRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF59E0B).withOpacity(0.7), size: 18),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _uploadReceipt(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      // ApiService ile POST isteği at
      final response = await ApiService.post('/api/receipts', {
        'imageBase64': base64Image,
        'method': 'OCR_MOBILE'
      });

      if (!mounted) return;

      if (response.statusCode == 201 || response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fiş başarıyla yüklendi ve AI analizine gönderildi!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Go back to dashboard
      } else {
        if (response.statusCode == 401) {
           _showError('Oturum süresi dolmuş. Lütfen tekrar giriş yapın.');
        } else {
           _showError(response.error ?? 'Yükleme başarısız.');
        }
      }
    } catch (e) {
      _showError('Sunucu bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Fiş Fotoğrafı Çek'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          // Target frame overlay
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF59E0B), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFF59E0B)),
                    const SizedBox(height: 16),
                    Text(
                      _processingStage.isNotEmpty ? _processingStage : 'Yükleniyor ve AI Analiz Ediliyor...',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isUploading
          ? null
          : FloatingActionButton(
              onPressed: _takePictureAndUpload,
              backgroundColor: const Color(0xFFF59E0B),
              child: const Icon(Icons.camera, color: Colors.black, size: 32),
            ),
    );
  }
}
