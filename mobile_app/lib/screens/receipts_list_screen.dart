import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
      SnackBar(content: Text(msg), backgroundColor: AppTheme.statusRejected),
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
      case 'approved':      return AppTheme.statusApproved;
      case 'rejected':      return AppTheme.statusRejected;
      case 'flagged':       return AppTheme.statusFlagged;
      case 'aiprocessing':  return AppTheme.statusAiProcessing;
      default:              return AppTheme.statusPending;
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
        ? AppTheme.statusRejected
        : score >= 40
            ? AppTheme.statusPending
            : AppTheme.statusApproved;
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
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Fişlerim', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _fetchReceipts,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // Durum Filtresi
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
                      color: isAct ? AppTheme.primaryGold : AppTheme.surfaceGlass,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isAct ? AppTheme.primaryGold : AppTheme.primaryGold.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isAct ? AppTheme.bgDark : AppTheme.textMuted,
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

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : RefreshIndicator(
                    color: AppTheme.primaryGold,
                    onRefresh: _fetchReceipts,
                    child: _filteredReceipts.isEmpty
                        ? const Center(
                            child: Text('Kayıt bulunamadı.', style: TextStyle(color: AppTheme.textMuted)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredReceipts.length,
                            itemBuilder: (ctx, i) {
                              final r      = _filteredReceipts[i];
                              final status = (r['status'] as String?) ?? 'pending';
                              final sc     = _getStatusColor(status);
                              final bool isHighRisk = (r['fraudScore'] != null && r['fraudScore'] >= 60);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceGlass,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 2))],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(left: BorderSide(color: isHighRisk ? AppTheme.statusRejected : Colors.transparent, width: 3)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          // Kategori ikonu
                                          Container(
                                            width: 48, height: 48,
                                            decoration: BoxDecoration(
                                              color: sc.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: sc.withOpacity(0.2)),
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
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '${r['receiptDate'] ?? ''} · ${_getCategoryText(r['category'])}',
                                                      style: const TextStyle(color: AppTheme.textDarkMuted, fontSize: 12),
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
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: sc.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: sc.withOpacity(0.2)),
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
