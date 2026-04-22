import 'package:flutter/material.dart';
import 'create_bill_screen.dart';
import 'bill_detail_screen.dart';
import 'settings_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    try {
      final data = await supabase
          .from('bills')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _bills = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ดึงข้อมูลไม่ได้ กรุณาลองใหม่')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  double get _totalAmount {
    return _bills.fold<double>(0, (sum, bill) {
      final amount = (bill['total_amount'] as num?)?.toDouble() ?? 0;
      return sum + amount;
    });
  }

  String _formatAmount(num amount) {
    final isWhole = amount % 1 == 0;
    return isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  Future<_EditBillPayload?> _showEditBillDialog({
    required String initialTitle,
    required double initialAmount,
    required List<String> initialParticipants,
  }) async {
    final titleController = TextEditingController(text: initialTitle);
    final amountController = TextEditingController(
      text: _formatAmount(initialAmount),
    );
    final participantsController = TextEditingController(
      text: initialParticipants.join(', '),
    );

    final payload = await showDialog<_EditBillPayload>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('แก้ไขบิล'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อบิล',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ยอดรวม (บาท)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: participantsController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'รายชื่อคนหาร',
                    hintText: 'คั่นด้วย , หรือขึ้นบรรทัดใหม่',
                    prefixIcon: Icon(Icons.groups_2_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                final participants = participantsController.text
                    .split(RegExp(r'[,\n]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                if (title.isEmpty || amount <= 0 || participants.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'กรุณากรอกชื่อบิล ยอดรวม และรายชื่อคนหารให้ครบ',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  _EditBillPayload(
                    title: title,
                    amount: amount,
                    participants: participants,
                  ),
                );
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    amountController.dispose();
    participantsController.dispose();

    return payload;
  }

  Future<void> _editBill(Map<String, dynamic> bill) async {
    try {
      final participantRows = await supabase
          .from('participants')
          .select('name')
          .eq('bill_id', bill['id'])
          .order('created_at', ascending: true);

      final participantNames = List<Map<String, dynamic>>.from(participantRows)
          .map((row) => (row['name'] as String?)?.trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final amount = (bill['total_amount'] as num?)?.toDouble() ?? 0;
      final title = (bill['title'] as String?) ?? '';

      final payload = await _showEditBillDialog(
        initialTitle: title,
        initialAmount: amount,
        initialParticipants: participantNames,
      );

      if (payload == null) return;

      final billId = bill['id'];
      await supabase
          .from('bills')
          .update({'title': payload.title, 'total_amount': payload.amount})
          .eq('id', billId);

      final amountPerPerson = payload.amount / payload.participants.length;
      await supabase.from('participants').delete().eq('bill_id', billId);
      await supabase
          .from('participants')
          .insert(
            payload.participants
                .map(
                  (name) => {
                    'bill_id': billId,
                    'name': name,
                    'amount_owed': amountPerPerson,
                  },
                )
                .toList(),
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('แก้ไขบิลเรียบร้อย')));
        await _fetchBills();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แก้ไขบิลไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<void> _deleteBill(Map<String, dynamic> bill) async {
    final title = (bill['title'] as String?) ?? 'บิลนี้';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ลบบิล'),
          content: Text(
            'ต้องการลบ "$title" ใช่หรือไม่?\nข้อมูลผู้ร่วมจ่ายในบิลนี้จะถูกลบด้วย',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await supabase.from('bills').delete().eq('id', bill['id']);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบบิลเรียบร้อย')));
        await _fetchBills();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบบิลไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7A64), Color(0xFF1FA187)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปค่าใช้จ่าย',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '฿${_formatAmount(_totalAmount)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryBadge(
                icon: Icons.receipt_long_rounded,
                text: '${_bills.length} บิล',
              ),
              const SizedBox(width: 10),
              const _SummaryBadge(icon: Icons.group_rounded, text: 'พร้อมแชร์'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 58, color: Color(0xFF88A8A2)),
          SizedBox(height: 12),
          Text(
            'ยังไม่มีบิลในประวัติ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'กดปุ่ม + เพื่อเริ่มสร้างบิลแรกได้เลย',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5E7370)),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final amount = (bill['total_amount'] as num?)?.toDouble() ?? 0;
    final title = (bill['title'] as String?) ?? 'ไม่มีชื่อบิล';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillDetailScreen(bill: bill),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: bill['image_url'] != null
                      ? Image.network(
                          bill['image_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFE3EEEB),
                              child: const Icon(Icons.broken_image_outlined),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFFE3EEEB),
                          child: const Icon(
                            Icons.receipt_rounded,
                            color: Color(0xFF4D7C73),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'แตะเพื่อดูรายละเอียด',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF6F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '฿${_formatAmount(amount)}',
                  style: const TextStyle(
                    color: Color(0xFF0E7A64),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<_BillCardAction>(
                onSelected: (action) {
                  if (action == _BillCardAction.edit) {
                    _editBill(bill);
                    return;
                  }
                  _deleteBill(bill);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<_BillCardAction>(
                    value: _BillCardAction.edit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('แก้ไข'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_BillCardAction>(
                    value: _BillCardAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('ลบ'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Splitmate History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBills,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchBills,
              child: ListView(
                children: [
                  _buildHeader(),
                  if (_bills.isEmpty)
                    _buildEmptyState()
                  else
                    ..._bills.map(_buildBillCard),
                  const SizedBox(height: 88),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateBillScreen()),
          );
          _fetchBills(); // Refresh after creating a new bill
        },
        backgroundColor: const Color(0xFF0E7A64),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditBillPayload {
  final String title;
  final double amount;
  final List<String> participants;

  const _EditBillPayload({
    required this.title,
    required this.amount,
    required this.participants,
  });
}

enum _BillCardAction { edit, delete }
