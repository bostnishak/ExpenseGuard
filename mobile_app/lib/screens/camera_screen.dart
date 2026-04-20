import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:io';

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

    setState(() => _isUploading = true);

    try {
      final image = await _controller!.takePicture();
      await _uploadReceipt(image.path);
    } catch (e) {
      _showError('Fotoğraf çekilirken hata oluştu: $e');
      setState(() => _isUploading = false);
    }
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
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFF59E0B)),
                    SizedBox(height: 16),
                    Text('Yükleniyor ve AI Analiz Ediliyor...', style: TextStyle(fontWeight: FontWeight.bold)),
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
