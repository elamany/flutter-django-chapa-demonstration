// import 'package:chapasdk/chapasdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/format.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/donate_bloc.dart';
import '../bloc/donate_event.dart';
import '../bloc/donate_state.dart';
import '../screens/chapa_checkout_screen.dart';

/// Opens the donate form as a modal bottom sheet.
///
/// Returns Chapa's result message when the flow ends, or null if the
/// user dismissed the sheet without submitting.
Future<({String status, double amount})?> showDonateSheet({
  required BuildContext context,
  required int campaignId,
  required String campaignTitle,
}) {
  return showModalBottomSheet<({String status, double amount})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => DonateBloc(),
      child: DonateSheet(
        campaignId: campaignId,
        campaignTitle: campaignTitle,
      ),
    ),
  );
}

class DonateSheet extends StatefulWidget {
  const DonateSheet({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
  });

  final int campaignId;
  final String campaignTitle;

  @override
  State<DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<DonateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
String _nameBeforeAnonymous = '';
  bool _isAnonymous = false;
  bool _sdkLaunched = false;

  static const _quickAmounts = <double>[100, 500, 1000, 5000];

  @override
  void initState() {
    super.initState();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final user = authState.user;
      final first = user.firstName.trim();
      final last = user.lastName.trim();
      final fullName = '$first $last'.trim();
      if (fullName.isNotEmpty) {
        _nameCtrl.text = fullName;
      }

      if (user.email.isNotEmpty) {
        _emailCtrl.text = user.email;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.trim());

    context.read<DonateBloc>().add(
          DonateSubmitted(
            campaignId: widget.campaignId,
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            amount: amount,
            isAnonymous: _isAnonymous,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<DonateBloc, DonateState>(
      listener: (context, state) async {
        if (state is! DonateSuccess) return;
        if (_sdkLaunched) return;
        _sdkLaunched = true;

        final checkoutUrl = state.initiation.checkoutUrl;
        if (checkoutUrl.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No checkout URL returned.')),
            );
          }
          return;
        }

        // Push the webview on top of the sheet.
        final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => ChapaCheckoutScreen(
            checkoutUrl: checkoutUrl,
            txRef: state.initiation.txRef,
          ),
        ),
      );

        // Now pop the sheet with the payment status.
          if (!mounted) return;
          final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
          Navigator.of(context).pop((
            status: result ?? 'paymentCancelled',
            amount: amount,
          ));
      },
      child: BlocBuilder<DonateBloc, DonateState>(
        builder: (context, state) {
          final submitting = state is DonateLoading;
          final error = state is DonateFailure ? state.message : null;

          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets),
            child: Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Text(
                        'Donate to',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.campaignTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),

                      // Amount
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount (ETB)',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter an amount';
                          }
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null) return 'Enter a valid number';
                          if (parsed < 1) return 'Minimum is 1 ETB';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Quick-amount chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickAmounts.map((a) {
                          return ActionChip(
                            label: Text('${Formatters.money(a)} ETB'),
                            onPressed: () {
                              _amountCtrl.text = a.toStringAsFixed(0);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Name
                      TextFormField(
                        controller: _nameCtrl,
                        enabled: !_isAnonymous,
                        decoration: InputDecoration(
                          labelText: 'Your name',
                          prefixIcon: const Icon(Icons.person_outline),
                          helperText: _isAnonymous
                              ? 'Hidden — you will appear as "Anonymous"'
                              : null,
                        ),
                        validator: (v) {
                          if (_isAnonymous) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          helperText:
                              'Chapa will send your receipt to this email',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Anonymous toggle
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isAnonymous,
                        onChanged: submitting
                            ? null
                            : (v) {
                                setState(() {
                                  if (v) {
                                    _nameBeforeAnonymous = _nameCtrl.text;
                                    _nameCtrl.text = 'Anonymous';
                                  } else {
                                    _nameCtrl.text =
                                        _nameBeforeAnonymous.trim() == 'Anonymous'
                                            ? ''
                                            : _nameBeforeAnonymous;
                                  }
                                  _isAnonymous = v;
                                });
                              },
                        title: const Text('Donate anonymously'),
                        subtitle: const Text(
                          'Your name will not appear on the public list',
                        ),
                      ),

                      // Error banner
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: scheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Submit
                      ElevatedButton(
                        onPressed: submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 33, 72, 243),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.blue.withValues(alpha: 0.6),
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Continue to payment'),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'You will be redirected to Chapa to complete the payment.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}