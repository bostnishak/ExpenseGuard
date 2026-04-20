import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Fişlerin detaylı listesini gösteren ekran.
/// Durum, fraud skoru ve kategori bazlı filtreleme + pull-to-refresh destekler.
class ReceiptsListScreen extends StatefulWidget {
  const ReceiptsListScreen({super.key});

  @override
  State<ReceiptsListScreen> createState() => _ReceiptsListScreenState();
}

class _ReceiptsListScreenState extends State<ReceiptsListScreen> {
  List<dynamic> _receipts = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  static const _statusFilters = {
    'all': 'Tümü',
    'pending': 'Bekleyen',
    'approved': 'Onaylı',
    'rejected': 'Reddedildi',
    'flagged': 'Riskli',
  };

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    setState(() => _isLoading = true);
    final response = await ApiService.getMyReceipts(page: 1, pageSize: 50);
    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _receipts  = response.data?['items'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      _showError(response.error ?? 'Veriler yüklenemedi');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  List<dynamic> get _filteredReceipts {
    if (_filterStatus == 'all') return _receipts;
    return _receipts
        .where((r) => (r['status'] as String).toLowerCase() == _filterStatus)
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':      return const Color(0xFF34D399);
      case 'rejected':      return const Color(0xFFF87171);
      case 'flagged':       return const Color(0xFFFCA5A5);
      case 'aiprocessing':  return const Color(0xFFC084FC);
      default:              return const Color(0xFFFBBF24);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':      return 'ONAYLI';
      case 'rejected':      return 'REDDEDİLDİ';
      case 'flagged':       return 'RİSKLİ';
      case 'aiprocessing':  return 'AI İŞLİYOR';
      case 'pending':       return 'BEKLİYOR';
      default:              return 'BEKLİYOR';
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'food':          return Icons.restaurant;
      case 'transport':     return Icons.directions_car;
      case 'accommodation': return Icons.hotel;
      case 'fuel':          return Icons.local_gas_station;
      case 'office':        return Icons.business_center;
      case 'entertainment': return Icons.theater_comedy;
      default:              return Icons.receipt_long;
    }
  }

  String _getCategoryText(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'food':          return 'Yemek';
      case 'transport':     return 'Ulaşım';
      case 'accommodation': return 'Konaklama';
      case 'fuel':          return 'Yakıt';
      case 'office':        return 'Ofis';
      case 'entertainment': return 'Eğlence';
      default:              return 'Diğer';
    }
  }

  Widget _buildFraudBadge(dynamic fraudScore) {
    if (fraudScore == null) return const SizedBox.shrink();
    final score = (fraudScore as num).toInt();
    final color = score >= 70
        ? Colors.red
        : score >= 40
            ? Colors.orange
            : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '⚠ $score',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0A06),
      appBar: AppBar(
        title: const Text('Fişlerim', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF1C1109),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReceipts,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Durum Filtresi (Türkçe) ──
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _statusFilters.entries.map((entry) {
                final isAct = _filterStatus == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _filterStatus = entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isAct ? const Color(0xFFF59E0B) : const Color(0xFF1C1109),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isAct ? const Color(0xFFF59E0B) : const Color(0x2EF59E0B)),
                    ),
                    child: Center(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isAct ? const Color(0xFF0F0A06) : const Color(0xFFC4A882),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Liste ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : RefreshIndicator(
                    color: const Color(0xFFF59E0B),
                    onRefresh: _fetchReceipts,
                    child: _filteredReceipts.isEmpty
                        ? const Center(
                            child: Text('Kayıt bulunamadı.', style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredReceipts.length,
                            itemBuilder: (ctx, i) {
                              final r      = _filteredReceipts[i];
                              final status = (r['status'] as String?) ?? 'pending';
                              final sc     = _getStatusColor(status);
                              return Card(
                                color: const Color(0xFF1C1109),
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0x2EF59E0B), width: 1),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Kategori ikonu
                                      Container(
                                        width: 46, height: 46,
                                        decoration: BoxDecoration(
                                          color: sc.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(_getCategoryIcon(r['category']), color: sc, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      // Bilgiler
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r['vendorName'] ?? 'Bilinmiyor',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFDF4E7)),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '${r['receiptDate'] ?? ''} · ${_getCategoryText(r['category'])}',
                                                  style: const TextStyle(color: Color(0xFF7A6347), fontSize: 12),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildFraudBadge(r['fraudScore']),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Tutar ve durum
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₺${r['amount'] ?? '—'}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFEDE8DF)),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: sc.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _getStatusText(status),
                                              style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
