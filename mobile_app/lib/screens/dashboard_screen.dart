import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    final response = await ApiService.getMyReceipts();
    
    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _receipts = response.data?['items'] ?? [];
        _isLoading = false;
      });
    } else {
      if (response.statusCode == 401) {
        _logout();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return const Color(0xFF34D399);
      case 'rejected': return const Color(0xFFF87171);
      case 'flagged': return const Color(0xFFFCA5A5);
      case 'aiprocessing': return const Color(0xFFC084FC);
      default: return const Color(0xFFFBBF24);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return 'ONAYLI';
      case 'rejected': return 'REDDEDİLDİ';
      case 'flagged': return 'RİSKLİ';
      case 'aiprocessing': return 'AI İŞLİYOR';
      case 'pending': return 'BEKLİYOR';
      default: return 'BEKLİYOR';
    }
  }

  String _getCategoryText(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'food': return 'Yemek';
      case 'transport': return 'Ulaşım';
      case 'accommodation': return 'Konaklama';
      case 'fuel': return 'Yakıt';
      case 'office': return 'Ofis';
      case 'entertainment': return 'Eğlence';
      default: return 'Diğer';
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'accommodation': return Icons.hotel;
      case 'fuel': return Icons.local_gas_station;
      case 'office': return Icons.business_center;
      case 'entertainment': return Icons.theater_comedy;
      default: return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    // KPI hesaplamaları
    final totalAmount = _receipts.fold<double>(0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
    final approvedCount = _receipts.where((r) => (r['status'] as String?)?.toLowerCase() == 'approved').length;
    final flaggedCount = _receipts.where((r) => (r['status'] as String?)?.toLowerCase() == 'flagged').length;
    final pendingCount = _receipts.where((r) {
      final s = (r['status'] as String?)?.toLowerCase() ?? '';
      return s == 'pending' || s == 'aiprocessing';
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0A06),
      appBar: AppBar(
        title: const Text('Özet', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF1C1109),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReceipts, tooltip: 'Yenile'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : RefreshIndicator(
              color: const Color(0xFFF59E0B),
              onRefresh: _fetchReceipts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── KPI Kartları ──
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard('Toplam', '₺${totalAmount.toStringAsFixed(0)}', Icons.account_balance_wallet, const Color(0xFF60A5FA))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildKpiCard('Onaylı', '$approvedCount', Icons.check_circle_outline, const Color(0xFF34D399))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard('Riskli', '$flaggedCount', Icons.warning_amber_rounded, const Color(0xFFF87171))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildKpiCard('Bekleyen', '$pendingCount', Icons.hourglass_empty, const Color(0xFFC084FC))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Son Fişler Başlık ──
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, color: Color(0xFFF59E0B), size: 18),
                      SizedBox(width: 8),
                      Text('Son Fişler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFFDF4E7))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Fiş Listesi ──
                  if (_receipts.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('📭 Henüz fiş bulunmuyor.', style: TextStyle(color: Color(0xFFC4A882))),
                    ))
                  else
                    ...List.generate(_receipts.length, (index) {
                      final r = _receipts[index];
                      final status = (r['status'] as String?) ?? 'pending';
                      final statusColor = _getStatusColor(status);
                      final bool isHighRisk = (r['fraudScore'] != null && r['fraudScore'] >= 60);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1109),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x2EF59E0B)),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 2))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(left: BorderSide(color: isHighRisk ? const Color(0xFFF87171) : Colors.transparent, width: 3)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withOpacity(0.2)),
                                ),
                                child: Icon(_getCategoryIcon(r['category']), color: statusColor, size: 22),
                              ),
                              title: Text(r['vendorName'] ?? 'Bilinmiyor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFDF4E7))),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${r['receiptDate']} · ${_getCategoryText(r['category'])}',
                                  style: const TextStyle(color: Color(0xFF7A6347), fontSize: 12),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₺${r['amount'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFEDE8DF))),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor.withOpacity(0.2)),
                                    ),
                                    child: Text(_getStatusText(status), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1109),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2EF59E0B)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFFC4A882), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Color(0xFFFDF4E7), fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
