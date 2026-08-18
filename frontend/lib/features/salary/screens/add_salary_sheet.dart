import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
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
        },
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Salary configuration added for ${widget.employeeName}'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.wallet_add_1, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configure Base Salary',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                          ),
                          Text(
                            widget.employeeName,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle, size: 20),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: context.border),
              const SizedBox(height: 16),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Basic Salary (NPR) *',
                  prefixIcon: Icon(Iconsax.money, size: 18),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Basic salary is required' : null,
                onSaved: (v) => _basicSalary = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 14),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Remote Allowance (NPR)',
                  prefixIcon: Icon(Iconsax.buildings, size: 18),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                initialValue: '0',
                onSaved: (v) => _remoteSalary = double.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 22),

              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.save_2, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Save Salary Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
