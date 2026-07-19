import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class AddEmployeeSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const AddEmployeeSheet({super.key, required this.onSuccess});

  @override
  State<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  
  String _fname = '', _lname = '', _email = '', _password = '';
  String _phone = '', _dob = '2000-01-01', _gender = 'male';
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      await ApiService().post(
        '${AppConstants.organizationBase}/employees/',
        data: {
          'user': {
            'first_name': _fname,
            'last_name': _lname,
            'email': _email,
            'password': _password,
          },
          'post': 1, // Default seeded post
          'gender': _gender,
          'date_of_birth': _dob,
          'father_name': 'N/A',
          'phone_no': _phone,
          'official_email': _email,
          'personal_email': _email,
          'is_active': true,
          'employee_type': 'full_time',
        }
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              const Text('Add New Employee', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  onSaved: (v) => _fname = v!,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  onSaved: (v) => _lname = v!,
                )),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: (v) => v!.contains('@') ? null : 'Invalid email',
                onSaved: (v) => _email = v!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                onSaved: (v) => _password = v!,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
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
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                )),
              ]),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add Employee')
              )
            ],
          ),
        ),
      ),
    );
  }
}
