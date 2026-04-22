import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../main.dart';

class BillDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bill;

  const BillDetailScreen({super.key, required this.bill});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  String _promptPayNumber = '';

  String _formatAmount(num amount) {
    final isWhole = amount % 1 == 0;
    return isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  double get _participantsTotal {
    return _participants.fold<double>(0, (sum, item) {
      final amount = (item['amount_owed'] as num?)?.toDouble() ?? 0;
      return sum + amount;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _promptPayNumber = prefs.getString('promptpay_number') ?? '';

      final data = await supabase
          .from('participants')
          .select()
          .eq('bill_id', widget.bill['id']);

      if (mounted) {
        setState(() {
          _participants = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่สามารถดึงข้อมูลได้')));
        setState(() => _isLoading = false);
      }
    }
  }

  // Generate PromptPay TLV String loosely based on standard
  String _generatePromptPayPayload(String accId, double amount) {
    if (accId.isEmpty) return '';
    // A proper PromptPay EMVCo payload generator should be used for production.
    // For this prototype, we'll try a basic scheme if possible or just encode the number.
    // Real generation is complex, here is a simplified mock or text intent.
    // However, qr_flutter just renders text. By formatting it nicely we get a neat result.
    final target = accId.replaceAll(RegExp(r'\D'), '');
    return "PROMPTPAY:$target?amount=$amount";
  }

  @override
  Widget build(BuildContext context) {
    final billAmount = (widget.bill['total_amount'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.bill['title'] ?? 'รายละเอียดบิล')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 240,
                      child: widget.bill['image_url'] != null
                          ? Image.network(
                              widget.bill['image_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const _ReceiptPlaceholder();
                              },
                            )
                          : const _ReceiptPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE9F5F0), Color(0xFFF6FAF9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยอดรวมทั้งหมด',
                          style: TextStyle(
                            color: Color(0xFF496865),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '฿${_formatAmount(billAmount)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E7A64),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _StatPill(
                              icon: Icons.group_rounded,
                              label: '${_participants.length} คน',
                            ),
                            const SizedBox(width: 8),
                            _StatPill(
                              icon: Icons.balance_rounded,
                              label:
                                  'รวม ฿${_formatAmount(_participantsTotal)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'คนร่วมหาร',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final p = _participants[index];
                      final amount =
                          (p['amount_owed'] as num?)?.toDouble() ?? 0;
                      final name = p['name']?.toString() ?? '-';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE0F0EC),
                            foregroundColor: const Color(0xFF0E7A64),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('ยอดที่ต้องจ่าย'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF6F4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '฿${_formatAmount(amount)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0E7A64),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_promptPayNumber.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E2E2)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'สแกนจ่ายผ่าน PromptPay',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3932),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'เข้าบัญชี: $_promptPayNumber',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _generatePromptPayPayload(
                                _promptPayNumber,
                                billAmount,
                              ),
                              version: QrVersions.auto,
                              size: 160.0,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF0E7A64),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0E7A64),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ReceiptPlaceholder extends StatelessWidget {
  const _ReceiptPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E7A64), Color(0xFF1FA187)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.receipt_long_rounded,
          size: 72,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0E7A64)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0E7A64),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
