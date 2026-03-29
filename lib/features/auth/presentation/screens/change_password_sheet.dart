import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';

/// Bottom sheet para alterar senha (usuário autenticado).
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMsg;
  String? _successMsg;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.primary, size: 28),
                SizedBox(width: 8),
                Text(
                  'Alterar Senha',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Error
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            // Success
            if (_successMsg != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_successMsg!, style: const TextStyle(color: Colors.green, fontSize: 13))),
                  ],
                ),
              ),
            // Current password
            TextField(
              controller: _currentController,
              keyboardType: TextInputType.number,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                hintText: 'Senha atual',
                prefixIcon: const Icon(Icons.lock_open_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            // New password
            TextField(
              controller: _newController,
              keyboardType: TextInputType.number,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                hintText: 'Nova senha (somente números)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            // Confirm password
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                hintText: 'Confirmar nova senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_isLoading ? 'Alterando...' : 'Alterar Senha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final current = _currentController.text.trim();
    final newPass = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty) {
      setState(() => _errorMsg = 'Digite sua senha atual.');
      return;
    }
    if (newPass.length < 4) {
      setState(() => _errorMsg = 'Nova senha deve ter no mínimo 4 dígitos.');
      return;
    }
    if (int.tryParse(newPass) == null) {
      setState(() => _errorMsg = 'A senha deve conter apenas números.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _errorMsg = 'As senhas não coincidem.');
      return;
    }
    if (newPass == current) {
      setState(() => _errorMsg = 'A nova senha deve ser diferente da atual.');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; _successMsg = null; });

    try {
      final result = await Supabase.instance.client.rpc(
        'change_user_password',
        params: {
          'current_password': current,
          'new_password': newPass,
        },
      );

      if (result != null && result['success'] == true) {
        setState(() {
          _isLoading = false;
          _successMsg = 'Senha alterada com sucesso!';
          _currentController.clear();
          _newController.clear();
          _confirmController.clear();
        });
        // Close after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = result?['error'] ?? 'Erro ao alterar senha.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Erro ao alterar senha. Tente novamente.';
      });
    }
  }
}
