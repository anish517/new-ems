import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class AddSalarySheet extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  const AddSalarySheet({super.key, required this.employeeId, required this.employeeName});

  @override
  State<AddSalarySheet> createState() => _AddSalarySheetState();
}

class _AddSalarySheetState extends State<AddSalarySheet> {
  final _formKey = GlobalKey<FormState>();
  
  double _basicSalary = 0;
  double _remoteSalary = 0;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      await ApiService().post(
        '${AppConstants.salaryBase}/salary/',
        data: {
          'employee': widget.employeeId,
          'basic_salary': _basicSalary,
          'remote_salary': _remoteSalary,
        }
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salary added successfully!'), backgroundColor: AppColors.success)
        );
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
              Text('Add Salary for ${widget.employeeName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Basic Salary (NPR)'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _basicSalary = double.parse(v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Remote Allowance (NPR)'),
                keyboardType: TextInputType.number,
                initialValue: '0',
                onSaved: (v) => _remoteSalary = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Salary Details')
              )
            ],
          ),
        ),
      ),
    );
  }
}
