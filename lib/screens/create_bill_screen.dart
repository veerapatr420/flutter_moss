import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _participantsController =
      TextEditingController(); // ex: แบงค์, มิ้นท์, มอส

  XFile? _image;
  bool _isLoading = false;
  int _personCount = 0;
  double _amountPerPerson = 0;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updatePreview);
    _participantsController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _participantsController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final names = _participantsController.text
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _personCount = names.length;
      _amountPerPerson = _personCount > 0 ? amount / _personCount : 0;
    });
  }

  Future<void> _showImageSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('ถ่ายรูปใบเสร็จ'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('เลือกรูปจาก Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );

    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
      });
    }
  }

  Future<void> _pickImage() async {
    await _showImageSourcePicker();
  }

  Future<void> _saveBill() async {
    if (_titleController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _participantsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    final double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยอดรวมต้องมากกว่า 0')));
      return;
    }

    // Split names
    final names = _participantsController.text
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุชื่อคนจ่ายร่วมอย่างน้อย 1 คน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;

      // 1. Upload Image (If any)
      if (_image != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${p.basename(_image!.path)}';
        final filePath =
            'public/$fileName'; // Changed path since there's no userId

        final imageBytes = await _image!.readAsBytes();
        await supabase.storage
            .from('receipts')
            .uploadBinary(
              filePath,
              imageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        imageUrl = supabase.storage.from('receipts').getPublicUrl(filePath);
      }

      // 2. Insert Bill
      final billResponse = await supabase
          .from('bills')
          .insert({
            'title': _titleController.text,
            'total_amount': amount,
            'image_url': imageUrl,
          })
          .select()
          .single();

      final billId = billResponse['id'];

      // 3. Calculate and Insert Participants
      final double amountPerPerson = amount / names.length;
      final participantsData = names
          .map(
            (name) => {
              'bill_id': billId,
              'name': name,
              'amount_owed': amountPerPerson,
            },
          )
          .toList();

      await supabase.from('participants').insert(participantsData);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatAmount(double amount) {
    final isWhole = amount % 1 == 0;
    return isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างบิลใหม่')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE9F5F0), Color(0xFFF7FBFA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calculate_rounded,
                          color: Color(0xFF0E7A64),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _personCount > 0
                                ? 'ตอนนี้หาร $_personCount คน\nคนละ ฿${_formatAmount(_amountPerPerson)}'
                                : 'กรอกยอดรวมและรายชื่อ เพื่อดูยอดต่อคนอัตโนมัติ',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 210,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFFE6EFEC),
                          ),
                          child: _image != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: kIsWeb
                                      ? Image.network(
                                          _image!.path,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_image!.path),
                                          fit: BoxFit.cover,
                                        ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_rounded,
                                      size: 44,
                                      color: Color(0xFF4F6F69),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'แตะเพื่อถ่ายรูปหรือเลือกรูปใบเสร็จ',
                                      style: TextStyle(
                                        color: Color(0xFF4F6F69),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อบิล (เช่น ข้าวเย็น MBK)',
                              prefixIcon: Icon(Icons.edit_note_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'ยอดรวม (บาท)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _participantsController,
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'รายชื่อคนหาร',
                              hintText: 'แบงค์, มิ้นท์, เจ หรือขึ้นบรรทัดใหม่',
                              prefixIcon: Icon(Icons.groups_2_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveBill,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF0E7A64),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('บันทึกและคำนวณเงิน'),
                  ),
                ],
              ),
            ),
    );
  }
}
