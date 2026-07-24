import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

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
  String _phone = '', _gender = 'male', _employeeType = 'full_time';
  DateTime _dob = DateTime.now();
  final _dobCtrl = TextEditingController();
  bool _isLoading = false;

  // Address fields
  String _street = '', _district = '', _state = '';

  // Bank fields
  String _bankName = '', _accountNumber = '';

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      final user = widget.employee!['user'] ?? {};
      _fname = user['first_name'] ?? '';
      _lname = user['last_name'] ?? '';
      _email = user['email'] ?? '';
      _phone = widget.employee!['phone_no'] ?? '';
      _gender = widget.employee!['gender'] ?? 'male';
      _employeeType = widget.employee!['employee_type'] ?? 'full_time';
      if (widget.employee!['date_of_birth'] != null) {
        try {
          _dob = DateTime.parse(widget.employee!['date_of_birth']);
        } catch (_) {}
      }
    }
    _dobCtrl.text = "${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = "${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final data = {
        'user': {
          'first_name': _fname,
          'last_name': _lname,
          'email': _email,
          if (_password.isNotEmpty) 'password': _password,
        },
        'gender': _gender,
        'date_of_birth': "${_dob.year}-${_dob.month.toString().padLeft(2, '0')}-${_dob.day.toString().padLeft(2, '0')}",
        'phone_no': _phone,
      };

      int? employeeId;

      if (widget.employee == null) {
        data['post'] = 1; // Default post
        data['father_name'] = 'N/A';
        data['official_email'] = _email;
        data['personal_email'] = _email;
        data['is_active'] = true;
        data['employee_type'] = _employeeType;
        final res = await ApiService().post('${AppConstants.organizationBase}/employees/', data: data);
        employeeId = res.data['id'];
      } else {
        employeeId = widget.employee!['id'];
        // Ensure official and personal emails are also updated to match
        data['official_email'] = _email;
        data['personal_email'] = _email;
        await ApiService().patch('${AppConstants.organizationBase}/employees/$employeeId/', data: data);
      }

      // Save address if any fields are filled
      if (employeeId != null && (_street.isNotEmpty || _district.isNotEmpty || _state.isNotEmpty)) {
        try {
          await ApiService().post('${AppConstants.organizationBase}/addresses/', data: [
            {
              'employee': employeeId,
              'type': 'permanent',
              'street': _street,
              'district': _district,
              'state': _state,
            }
          ]);
        } catch (_) {}
      }

      // Save bank details if any fields are filled
      if (employeeId != null && (_bankName.isNotEmpty || _accountNumber.isNotEmpty)) {
        try {
          await ApiService().post('${AppConstants.organizationBase}/bank-details/', data: {
            'employee': employeeId,
            'bank_name': _bankName,
            'account_number': _accountNumber,
          });
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiService.getErrorMessage(e)}'), backgroundColor: AppColors.error)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.employee == null ? 'Add New Employee' : 'Edit Employee',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // ── Basic Info ──────────────────────────────────────
              Row(children: [
                Expanded(child: TextFormField(
                  initialValue: _fname,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  onSaved: (v) => _fname = v!,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  initialValue: _lname,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  onSaved: (v) => _lname = v!,
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: (v) => v!.contains('@') ? null : 'Invalid email',
                onSaved: (v) => _email = v!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(labelText: widget.employee == null ? 'Password' : 'Password (leave blank to keep current)'),
                obscureText: true,
                validator: (v) => (widget.employee == null && v!.length < 6) ? 'Min 6 chars' : null,
                onSaved: (v) => _password = v ?? '',
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  initialValue: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  onSaved: (v) => _phone = v ?? '',
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'others', child: Text('Others')),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _employeeType,
                  decoration: const InputDecoration(labelText: 'Employee Type'),
                  items: const [
                    DropdownMenuItem(value: 'full_time', child: Text('Full Time')),
                    DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                    DropdownMenuItem(value: 'intern', child: Text('Intern')),
                  ],
                  onChanged: (v) => setState(() => _employeeType = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _dobCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                )),
              ]),

              // ── Address ────────────────────────────────────────
              _sectionTitle('Address (Permanent)'),
              Row(children: [
                Expanded(child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Street'),
                  onSaved: (v) => _street = v ?? '',
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  decoration: const InputDecoration(labelText: 'District'),
                  onSaved: (v) => _district = v ?? '',
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'State / Province'),
                onSaved: (v) => _state = v ?? '',
              ),

              // ── Bank Details ───────────────────────────────────
              _sectionTitle('Bank Details'),
              Row(children: [
                Expanded(child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  onSaved: (v) => _bankName = v ?? '',
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Account Number'),
                  keyboardType: TextInputType.number,
                  onSaved: (v) => _accountNumber = v ?? '',
                )),
              ]),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.employee == null ? 'Add Employee' : 'Save Changes')
              )
            ],
          ),
        ),
      ),
    );
  }
}
