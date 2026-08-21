import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/nepali_date_picker.dart';

class _AttachedDocItem {
  final PlatformFile file;
  String customName;

  _AttachedDocItem({required this.file, required this.customName});
}

class AddEmployeeSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  final Map? employee;
  const AddEmployeeSheet({super.key, required this.onSuccess, this.employee});

  @override
  State<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();

  String _fname = '', _lname = '', _email = '', _password = '';
  String _phone = '', _gender = 'male', _employeeType = 'full_time', _maritalStatus = 'single';
  NepaliDateTime _dob = NepaliDateTime(2055, 1, 1);
  final _dobCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingDetails = false;

  // Designation (Post) & Custom entry
  int? _selectedPostId;
  bool _isCustomDesignation = false;
  String _customDesignationTitle = '';
  final _customPostCtrl = TextEditingController();
  List<Map<String, dynamic>> _availablePosts = [];

  String _fatherName = '', _grandfatherName = '', _bloodGroup = 'A+', _altPhone = '';
  String _personalEmail = '';
  String _panNumber = '';
  final _panCtrl = TextEditingController();
  final List<_AttachedDocItem> _attachedDocs = [];
  List<dynamic> _existingDocuments = [];

  // Address fields
  int? _addressId;
  String _street = '', _district = '', _state = 'bagmati';

  // Bank fields
  int? _bankDetailId;
  String _bankName = '', _accountNumber = '', _accountName = '';

  @override
  void initState() {
    super.initState();
    _fetchPosts();

    if (widget.employee != null) {
      final user = widget.employee!['user'] ?? {};
      _fname = user['first_name'] ?? '';
      _lname = user['last_name'] ?? '';
      _email = user['email'] ?? '';
      _phone = widget.employee!['phone_no'] ?? '';
      _gender = widget.employee!['gender'] ?? 'male';
      _maritalStatus = widget.employee!['marital_status'] ?? 'single';
      _employeeType = widget.employee!['employee_type'] ?? 'full_time';
      _panNumber = widget.employee!['pan_number']?.toString() ??
          widget.employee!['pan']?.toString() ??
          '';
      _panCtrl.text = _panNumber;

      final postVal = widget.employee!['post'];
      if (postVal is int) {
        _selectedPostId = postVal;
      } else if (postVal is Map && postVal['id'] != null) {
        _selectedPostId = postVal['id'];
        if (postVal['title'] != null) {
          _customDesignationTitle = postVal['title'];
          _customPostCtrl.text = postVal['title'];
        }
      }

      if (widget.employee!['designation_title'] != null) {
        _customDesignationTitle = widget.employee!['designation_title'];
        _customPostCtrl.text = widget.employee!['designation_title'];
      }

      if (widget.employee!['date_of_birth'] != null) {
        try {
          _dob = NepaliDateTime.parse(widget.employee!['date_of_birth']);
        } catch (_) {}
      }
      _fatherName = widget.employee!['father_name'] ?? '';
      _grandfatherName = widget.employee!['grandfather_name'] ?? '';
      _bloodGroup = widget.employee!['blood_group'] ?? 'A+';
      _altPhone = widget.employee!['emergency_phone_number'] ??
          widget.employee!['alternative_contact_number'] ??
          '';
      _personalEmail = widget.employee!['personal_email'] ?? '';
      _fetchExtraDetails(widget.employee!['id']);
    }
    _dobCtrl.text =
        "${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _dobCtrl.dispose();
    _customPostCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    try {
      final res = await ApiService().get('${AppConstants.organizationBase}/posts/');
      final data = res.data is List ? res.data : (res.data['results'] ?? res.data);
      if (data is List && data.isNotEmpty) {
        if (mounted) {
          setState(() {
            _availablePosts = List<Map<String, dynamic>>.from(data);
            if (_selectedPostId == null || !_availablePosts.any((p) => p['id'] == _selectedPostId)) {
              _selectedPostId = _availablePosts.first['id'];
            }
          });
        }
      }
    } catch (_) {
      // Fallback defaults if offline
      if (mounted && _availablePosts.isEmpty) {
        setState(() {
          _availablePosts = [
            {'id': 1, 'title': 'Software Engineer'},
            {'id': 2, 'title': 'Senior Developer'},
            {'id': 3, 'title': 'Frontend Developer'},
            {'id': 4, 'title': 'Backend Developer'},
            {'id': 5, 'title': 'UI/UX Designer'},
            {'id': 6, 'title': 'Project Manager'},
            {'id': 7, 'title': 'HR Manager'},
            {'id': 8, 'title': 'Accountant / Finance'},
            {'id': 9, 'title': 'QA Tester'},
            {'id': 10, 'title': 'Intern'},
          ];
          _selectedPostId ??= 1;
        });
      }
    }
  }

  Future<void> _fetchExtraDetails(int empId) async {
    setState(() => _isLoadingDetails = true);
    try {
      final empRes = await ApiService()
          .get('${AppConstants.organizationBase}/employees/$empId/');
      if (empRes.data != null && empRes.data is Map) {
        final empData = empRes.data as Map;
        final fetchedPan = empData['pan_number']?.toString() ?? empData['pan']?.toString() ?? '';
        if (fetchedPan.isNotEmpty) {
          if (mounted) {
            setState(() {
              _panNumber = fetchedPan;
              _panCtrl.text = fetchedPan;
            });
          }
        }
      }

      final addrRes = await ApiService()
          .get('${AppConstants.organizationBase}/addresses/?employee=$empId');
      final addrs =
          addrRes.data is List ? addrRes.data : addrRes.data['results'];
      if (addrs != null && addrs.isNotEmpty) {
        final addr = addrs.first;
        _addressId = addr['id'];
        _street = addr['street'] ?? '';
        _district = addr['district'] ?? '';
        _state = addr['state'] ?? 'bagmati';
      }

      final bankRes = await ApiService().get(
          '${AppConstants.organizationBase}/bank-details/?employee=$empId');
      final banks =
          bankRes.data is List ? bankRes.data : bankRes.data['results'];
      if (banks != null && banks.isNotEmpty) {
        final bank = banks.first;
        _bankDetailId = bank['id'];
        _bankName = bank['bank_name'] ?? '';
        _accountName = bank['account_name'] ?? '';
        _accountNumber = bank['account_number'] ?? '';
      }

      final docRes = await ApiService()
          .get('${AppConstants.organizationBase}/documents/?employee=$empId');
      final docs = docRes.data is List ? docRes.data : docRes.data['results'];
      if (docs != null && docs.isNotEmpty) {
        _existingDocuments = docs;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  Future<void> _deleteDocument(int docId) async {
    try {
      await ApiService()
          .delete('${AppConstants.organizationBase}/documents/$docId/');
      setState(() {
        _existingDocuments.removeWhere((d) => d['id'] == docId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete document')),
        );
      }
    }
  }

  void _renameLocalDoc(_AttachedDocItem item) {
    final ctrl = TextEditingController(text: item.customName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Iconsax.edit_2, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Text('Rename Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Document Name',
            hintText: 'e.g. Citizenship Front, CV / Resume, PAN Card',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => item.customName = ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Name', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _previewLocalDoc(_AttachedDocItem item) {
    final ext = item.file.extension?.toLowerCase() ?? '';
    final isImg = ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext);
    final Uint8List? bytes = item.file.bytes;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.customName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ctx.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.file.name} • ${(item.file.size / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.close_circle, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: ctx.border, height: 1),
                const SizedBox(height: 14),
                if (isImg && bytes != null)
                  Expanded(
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (isImg && item.file.path != null)
                  Expanded(
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          child: Image.file(
                            File(item.file.path!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.document_text,
                              size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.file.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ctx.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ext.toUpperCase().isEmpty ? 'DOCUMENT' : ext.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'File ready to be uploaded upon saving employee account.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _renameExistingDoc(Map<String, dynamic> doc) {
    final ctrl = TextEditingController(text: doc['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Iconsax.edit_2, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Text('Rename Uploaded Document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Document Name',
            hintText: 'e.g. Citizenship Card, Offer Letter, Academic Certificate',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await ApiService().patch(
                    '${AppConstants.organizationBase}/documents/${doc['id']}/',
                    data: {'name': newName},
                  );
                  setState(() => doc['name'] = newName);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Document renamed successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to rename document'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Name',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _previewExistingDoc(Map<String, dynamic> doc) async {
    final String url = doc['file'] ?? '';
    final String name = doc['name'] ?? 'Document';
    final bool isImage = url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.webp');

    if (isImage && url.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: ctx.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ctx.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.close_circle, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Text('Failed to load image')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDialog<NepaliDateTime>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: 'Select Date of Birth (B.S.)',
        initial: _dob,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text =
            "${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Iconsax.warning_2, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Please correct the highlighted errors before saving.'),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    _formKey.currentState!.save();
    _panNumber = _panCtrl.text.trim();

    if (widget.employee == null && _attachedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Iconsax.document_upload, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Please attach at least one verification document (e.g. Citizenship, CV, PAN).'),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // If user typed a custom designation, create or resolve post first
      int postId = _selectedPostId ?? 1;
      if (_isCustomDesignation && _customDesignationTitle.trim().isNotEmpty) {
        try {
          final postRes = await ApiService().post(
            '${AppConstants.organizationBase}/posts/',
            data: {'title': _customDesignationTitle.trim()},
          );
          if (postRes.data != null && postRes.data['id'] != null) {
            postId = postRes.data['id'];
          }
        } catch (e) {
          debugPrint('Custom post creation fallback: $e');
        }
      }

      final dobStr =
          "${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}";

      final data = {
        'user': {
          'first_name': _fname.trim(),
          'last_name': _lname.trim(),
          'email': _email.trim(),
          if (_password.isNotEmpty) 'password': _password,
        },
        'post': postId,
        'gender': _gender,
        'marital_status': _maritalStatus,
        'pan_number': _panNumber.trim(),
        'date_of_birth': dobStr,
        'phone_no': _phone.trim(),
        'father_name': _fatherName.trim(),
        'grandfather_name': _grandfatherName.trim(),
        'blood_group': _bloodGroup,
        'emergency_phone_number': _altPhone.trim(),
        'official_email': _email.trim(),
        'personal_email': _personalEmail.isNotEmpty ? _personalEmail.trim() : _email.trim(),
        'employee_type': _employeeType,
      };

      int? employeeId;

      if (widget.employee == null) {
        data['is_active'] = true;
        final res = await ApiService()
            .post('${AppConstants.organizationBase}/employees/', data: data);
        employeeId = res.data['id'];
      } else {
        employeeId = widget.employee!['id'];
        await ApiService().patch(
            '${AppConstants.organizationBase}/employees/$employeeId/',
            data: data);
      }

      // Save Address (create or update even if cleared/empty)
      if (employeeId != null) {
        try {
          final addrData = {
            'employee': employeeId,
            'type': 'permanent',
            'street': _street.trim(),
            'district': _district.trim(),
            'state': _state.trim(),
          };
          if (_addressId != null) {
            await ApiService().patch(
                '${AppConstants.organizationBase}/addresses/$_addressId/',
                data: addrData);
          } else if (_street.trim().isNotEmpty || _district.trim().isNotEmpty || _state.trim().isNotEmpty) {
            await ApiService().post(
                '${AppConstants.organizationBase}/addresses/',
                data: [addrData]);
          }
        } catch (e) {
          debugPrint('Address save warning: $e');
        }
      }

      // Save Bank Details (create or update even if cleared/empty)
      if (employeeId != null) {
        try {
          final bankData = {
            'employee': employeeId,
            'bank_name': _bankName.trim(),
            'account_name': _accountName.isNotEmpty
                ? _accountName.trim()
                : '$_fname $_lname'.trim(),
            'account_number': _accountNumber.trim(),
          };
          if (_bankDetailId != null) {
            await ApiService().patch(
                '${AppConstants.organizationBase}/bank-details/$_bankDetailId/',
                data: bankData);
          } else if (_bankName.trim().isNotEmpty || _accountNumber.trim().isNotEmpty || _accountName.trim().isNotEmpty) {
            await ApiService().post(
                '${AppConstants.organizationBase}/bank-details/',
                data: bankData);
          }
        } catch (e) {
          debugPrint('Bank save warning: $e');
        }
      }

      // Upload Documents
      if (employeeId != null && _attachedDocs.isNotEmpty) {
        for (final item in _attachedDocs) {
          try {
            List<int> fileBytes;
            if (item.file.bytes != null) {
              fileBytes = item.file.bytes!;
            } else if (item.file.path != null) {
              fileBytes = await File(item.file.path!).readAsBytes();
            } else {
              continue;
            }

            final docName = item.customName.trim().isNotEmpty
                ? item.customName.trim()
                : item.file.name;

            final formData = FormData.fromMap({
              'employee': employeeId,
              'name': docName,
              'file':
                  MultipartFile.fromBytes(fileBytes, filename: item.file.name),
            });

            await ApiService().post(
                '${AppConstants.organizationBase}/documents/',
                data: formData);
          } catch (e) {
            debugPrint('Document upload warning: $e');
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(widget.employee == null
                    ? 'Employee created successfully!'
                    : 'Employee details updated successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = ApiService.getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.warning_2, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Validation Error: $errorMsg')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: _isLoadingDetails
              ? const SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                widget.employee == null
                                    ? Iconsax.user_add
                                    : Iconsax.user_edit,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.employee == null
                                      ? 'Add New Employee'
                                      : 'Edit Employee Profile',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Fields marked with * are strictly required',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Iconsax.close_circle, size: 22),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: context.border),

                    // ── 1. Account & Personal Info ──────────────────────
                    _buildSectionHeader('Account & Identity Info', Iconsax.user),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _fname,
                            decoration: const InputDecoration(
                              labelText: 'First Name *',
                              hintText: 'e.g. John',
                              prefixIcon: Icon(Iconsax.user, size: 18),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'First Name is required'
                                : null,
                            onSaved: (v) => _fname = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: _lname,
                            decoration: const InputDecoration(
                              labelText: 'Last Name *',
                              hintText: 'e.g. Doe',
                              prefixIcon: Icon(Iconsax.user, size: 18),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Last Name is required'
                                : null,
                            onSaved: (v) => _lname = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Designation (Dropdown or Manual Text Entry) ─────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Iconsax.award, size: 17, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Designation / Job Role *',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isCustomDesignation = !_isCustomDesignation;
                                    if (!_isCustomDesignation && _availablePosts.isNotEmpty) {
                                      _selectedPostId ??= _availablePosts.first['id'];
                                    }
                                  });
                                },
                                icon: Icon(
                                  _isCustomDesignation ? Iconsax.menu : Iconsax.edit_2,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  _isCustomDesignation ? 'Select from List' : '✍️ Type Custom Role',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isCustomDesignation)
                            TextFormField(
                              controller: _customPostCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Custom Designation Title *',
                                hintText: 'e.g. Senior Flutter Developer, Operations Lead',
                                prefixIcon: Icon(Iconsax.edit, size: 18),
                              ),
                              validator: (v) => (_isCustomDesignation && (v == null || v.trim().isEmpty))
                                  ? 'Please enter designation title'
                                  : null,
                              onChanged: (v) => _customDesignationTitle = v,
                              onSaved: (v) => _customDesignationTitle = v ?? '',
                            )
                          else if (_availablePosts.isNotEmpty)
                            DropdownButtonFormField<int>(
                              initialValue: _selectedPostId,
                              decoration: const InputDecoration(
                                labelText: 'Select Designation *',
                                prefixIcon: Icon(Iconsax.briefcase, size: 18),
                              ),
                              items: _availablePosts.map((post) {
                                return DropdownMenuItem<int>(
                                  value: post['id'] as int,
                                  child: Text(post['title']?.toString() ?? 'Designation'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedPostId = val);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Official Work Email *',
                              hintText: 'employee@company.com',
                              prefixIcon: Icon(Iconsax.sms, size: 18),
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Valid work email is required'
                                : null,
                            onSaved: (v) => _email = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: _personalEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Personal Email (Optional)',
                              hintText: 'personal@gmail.com',
                              prefixIcon: Icon(Iconsax.sms_tracking, size: 18),
                            ),
                            onSaved: (v) => _personalEmail = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Primary Phone Number *',
                              hintText: '98XXXXXXXX',
                              prefixIcon: Icon(Iconsax.call, size: 18),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Primary phone number is required'
                                : null,
                            onSaved: (v) => _phone = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _panCtrl,
                            decoration: const InputDecoration(
                              labelText: 'PAN Number (Optional)',
                              hintText: 'e.g. 123456789',
                              prefixIcon: Icon(Iconsax.receipt_item, size: 18),
                            ),
                            keyboardType: TextInputType.text,
                            onChanged: (v) => _panNumber = v,
                            onSaved: (v) => _panNumber = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender *',
                              prefixIcon: Icon(Iconsax.man, size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(value: 'female', child: Text('Female')),
                              DropdownMenuItem(value: 'others', child: Text('Others')),
                            ],
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _maritalStatus,
                            decoration: const InputDecoration(
                              labelText: 'Marital Status',
                              prefixIcon: Icon(Iconsax.heart, size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'single', child: Text('Single')),
                              DropdownMenuItem(value: 'married', child: Text('Married')),
                            ],
                            onChanged: (v) => setState(() => _maritalStatus = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _employeeType,
                            decoration: const InputDecoration(
                              labelText: 'Employment Type *',
                              prefixIcon: Icon(Iconsax.briefcase, size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'full_time', child: Text('Full Time')),
                              DropdownMenuItem(
                                  value: 'part_time', child: Text('Part Time')),
                              DropdownMenuItem(
                                  value: 'intern', child: Text('Intern')),
                            ],
                            onChanged: (v) =>
                                setState(() => _employeeType = v!),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _dobCtrl,
                            readOnly: true,
                            onTap: _pickDate,
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth (B.S.) *',
                              prefixIcon: Icon(Iconsax.calendar_1, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: widget.employee == null
                            ? 'Login Password *'
                            : 'Login Password (leave blank to keep unchanged)',
                        hintText: 'Min 6 characters',
                        prefixIcon: const Icon(Iconsax.lock, size: 18),
                      ),
                      obscureText: true,
                      validator: (v) =>
                          (widget.employee == null && (v == null || v.length < 6))
                              ? 'Password (min 6 characters) is required'
                              : null,
                      onSaved: (v) => _password = v ?? '',
                    ),

                    // ── 2. Family & Emergency Info ──────────────────────
                    _buildSectionHeader('Family & Emergency Details', Iconsax.people),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _fatherName,
                            decoration: const InputDecoration(
                              labelText: "Father's Full Name *",
                              hintText: 'Required by regulations',
                              prefixIcon: Icon(Iconsax.user, size: 18),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? "Father's Name is required"
                                : null,
                            onSaved: (v) => _fatherName = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: _grandfatherName,
                            decoration: const InputDecoration(
                              labelText: "Grandfather's Name",
                              hintText: 'Optional',
                              prefixIcon: Icon(Iconsax.user, size: 18),
                            ),
                            onSaved: (v) => _grandfatherName = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _bloodGroup,
                            decoration: const InputDecoration(
                              labelText: 'Blood Group',
                              prefixIcon: Icon(Iconsax.health, size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'A+', child: Text('A+')),
                              DropdownMenuItem(value: 'A-', child: Text('A-')),
                              DropdownMenuItem(value: 'B+', child: Text('B+')),
                              DropdownMenuItem(value: 'B-', child: Text('B-')),
                              DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                              DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                              DropdownMenuItem(value: 'O+', child: Text('O+')),
                              DropdownMenuItem(value: 'O-', child: Text('O-')),
                            ],
                            onChanged: (v) => setState(() => _bloodGroup = v!),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: _altPhone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Contact No.',
                              hintText: '98XXXXXXXX',
                              prefixIcon: Icon(Iconsax.call_calling, size: 18),
                            ),
                            onSaved: (v) => _altPhone = v ?? '',
                          ),
                        ),
                      ],
                    ),

                    // ── 3. Permanent Address ────────────────────────────
                    _buildSectionHeader('Permanent Address', Iconsax.location),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _street,
                            decoration: const InputDecoration(
                              labelText: 'Street / Municipality',
                              hintText: 'e.g. Putalisadak-04',
                              prefixIcon: Icon(Iconsax.map, size: 18),
                            ),
                            onSaved: (v) => _street = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: _district,
                            decoration: const InputDecoration(
                              labelText: 'District',
                              hintText: 'e.g. Kathmandu',
                              prefixIcon: Icon(Iconsax.buildings_2, size: 18),
                            ),
                            onSaved: (v) => _district = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: _state,
                      decoration: const InputDecoration(
                        labelText: 'State / Province',
                        prefixIcon: Icon(Iconsax.global, size: 18),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bagmati', child: Text('Bagmati Province')),
                        DropdownMenuItem(value: 'gandaki', child: Text('Gandaki Province')),
                        DropdownMenuItem(value: 'lumbini', child: Text('Lumbini Province')),
                        DropdownMenuItem(value: 'karnali', child: Text('Karnali Province')),
                        DropdownMenuItem(value: 'sudurpaschim', child: Text('Sudurpashchim Province')),
                        DropdownMenuItem(value: 'province_1', child: Text('Koshi Province (Province 1)')),
                        DropdownMenuItem(value: 'province_2', child: Text('Madhesh Province (Province 2)')),
                      ],
                      onChanged: (v) => setState(() => _state = v!),
                    ),

                    // ── 4. Bank Account Details ─────────────────────────
                    _buildSectionHeader('Bank Account for Payroll', Iconsax.card_pos),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _bankName,
                            decoration: const InputDecoration(
                              labelText: 'Bank Name',
                              hintText: 'e.g. Nabil Bank, Global IME',
                              prefixIcon: Icon(Iconsax.bank, size: 18),
                            ),
                            onSaved: (v) => _bankName = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: _accountName,
                            decoration: const InputDecoration(
                              labelText: 'Account Holder Name',
                              hintText: 'Name as in bank book',
                              prefixIcon: Icon(Iconsax.user_tag, size: 18),
                            ),
                            onSaved: (v) => _accountName = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      initialValue: _accountNumber,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                        hintText: '0123456789012',
                        prefixIcon: Icon(Iconsax.card, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _accountNumber = v ?? '',
                    ),

                    // ── 5. Documents ────────────────────────────────────
                    _buildSectionHeader('Verification Documents', Iconsax.document_upload),

                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
                        );
                        if (result != null) {
                          setState(() {
                            for (final file in result.files) {
                              final baseName = file.name.contains('.')
                                  ? file.name.substring(0, file.name.lastIndexOf('.'))
                                  : file.name;
                              _attachedDocs.add(_AttachedDocItem(file: file, customName: baseName));
                            }
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Iconsax.document_upload, color: AppColors.primary, size: 18),
                      label: Text(
                        widget.employee == null
                            ? 'Attach Documents (Citizenship / CV / PAN) *'
                            : 'Upload Additional Documents',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),

                    if (_attachedDocs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Attached Documents (Click to Rename / Preview):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      ..._attachedDocs.map((item) {
                        final ext = item.file.extension?.toLowerCase() ?? '';
                        final isImg = ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isImg ? Iconsax.image : Iconsax.document_text,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _renameLocalDoc(item),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.customName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.5,
                                                color: context.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Iconsax.edit_2, size: 14, color: AppColors.accent),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.file.name} • ${(item.file.size / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _previewLocalDoc(item),
                                icon: const Icon(Iconsax.eye, size: 18),
                                tooltip: 'Preview Document',
                                visualDensity: VisualDensity.compact,
                                color: AppColors.primary,
                              ),
                              IconButton(
                                onPressed: () => _renameLocalDoc(item),
                                icon: const Icon(Iconsax.edit_2, size: 18),
                                tooltip: 'Rename Document',
                                visualDensity: VisualDensity.compact,
                                color: AppColors.accent,
                              ),
                              IconButton(
                                onPressed: () => setState(() => _attachedDocs.remove(item)),
                                icon: const Icon(Iconsax.trash, size: 18),
                                tooltip: 'Remove',
                                visualDensity: VisualDensity.compact,
                                color: AppColors.error,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    if (_existingDocuments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Uploaded Documents on File:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ..._existingDocuments.map((doc) {
                        final String name = doc['name'] ?? 'Document';
                        final String url = doc['file'] ?? '';
                        final bool isImg = url.toLowerCase().endsWith('.png') ||
                            url.toLowerCase().endsWith('.jpg') ||
                            url.toLowerCase().endsWith('.jpeg') ||
                            url.toLowerCase().endsWith('.webp');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isImg ? Iconsax.image : Iconsax.document_text,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _renameExistingDoc(doc),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.5,
                                                color: context.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Iconsax.edit_2, size: 14, color: AppColors.accent),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      url.split('/').last,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _previewExistingDoc(doc),
                                icon: const Icon(Iconsax.eye, size: 18),
                                tooltip: 'Preview Document',
                                visualDensity: VisualDensity.compact,
                                color: AppColors.primary,
                              ),
                              IconButton(
                                onPressed: () => _renameExistingDoc(doc),
                                icon: const Icon(Iconsax.edit_2, size: 18),
                                tooltip: 'Rename Document',
                                visualDensity: VisualDensity.compact,
                                color: AppColors.accent,
                              ),
                              IconButton(
                                onPressed: () => _deleteDocument(doc['id']),
                                icon: const Icon(Iconsax.trash, size: 18),
                                tooltip: 'Delete Document',
                                visualDensity: VisualDensity.compact,
                                color: AppColors.error,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 32),

                    // Submit Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.employee == null ? Iconsax.user_add : Iconsax.tick_circle,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.employee == null
                                        ? 'Create Employee Account'
                                        : 'Save Profile Changes',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
