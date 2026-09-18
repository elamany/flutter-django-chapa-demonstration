import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../main/sign_in_prompt.dart';
import '../bloc/create_campaign_bloc.dart';
import '../bloc/create_campaign_event.dart';
import '../bloc/create_campaign_state.dart';
import 'my_campaign_detail_screen.dart';

class CreateCampaignScreen extends StatelessWidget {
  const CreateCampaignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const SignInPrompt(
            title: 'New Campaign',
            message:
                'To create a campaign, you need to sign in or create an account.',
            icon: Icons.add_circle_outline,
          );
        }

        return BlocProvider(
          create: (_) => CreateCampaignBloc(),
          child: const _CreateCampaignView(),
        );
      },
    );
  }
}

class _CreateCampaignView extends StatefulWidget {
  const _CreateCampaignView();

  @override
  State<_CreateCampaignView> createState() => _CreateCampaignViewState();
}

class _CreateCampaignViewState extends State<_CreateCampaignView> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  XFile? _image;

  static const _quickTargets = <double>[5000, 10000, 50000, 100000];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (file != null) {
        setState(() => _image = file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_image != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove image',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _image = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final target = double.parse(_targetCtrl.text.trim());

    context.read<CreateCampaignBloc>().add(
          CreateCampaignSubmitted(
            title: _titleCtrl.text.trim(),
            description: _descriptionCtrl.text.trim(),
            targetAmount: target,
            image: _image,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Campaign'),
      ),
      body: BlocConsumer<CreateCampaignBloc, CreateCampaignState>(
        listener: (context, state) {
          if (state is CreateCampaignSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Campaign created as draft.'),
                backgroundColor: Color(0xFF16A34A),
              ),
            );
            // Replace this screen with the manage view so the user
            // can review / submit for review right away.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MyCampaignDetailScreen(
                  campaignId: state.campaign.id,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final submitting = state is CreateCampaignLoading;
          final error = state is CreateCampaignFailure
              ? state.message
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image picker
                  _ImagePicker(
                    image: _image,
                    onTap: submitting ? null : _showImageOptions,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a cover image (recommended)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  TextFormField(
                    controller: _titleCtrl,
                    enabled: !submitting,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Campaign title',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Title is required';
                      }
                      if (v.trim().length < 5) {
                        return 'At least 5 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Description
                  TextFormField(
                    controller: _descriptionCtrl,
                    enabled: !submitting,
                    maxLines: 5,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Description is required';
                      }
                      if (v.trim().length < 20) {
                        return 'At least 20 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Target amount
                  TextFormField(
                    controller: _targetCtrl,
                    enabled: !submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Target amount (ETB)',
                      prefixIcon: Icon(Icons.flag_outlined),
                      helperText: 'How much do you want to raise?',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Target amount is required';
                      }
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null) return 'Enter a valid number';
                      if (parsed < 100) return 'Minimum is 100 ETB';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickTargets.map((t) {
                      return ActionChip(
                        label: Text('ETB ${_short(t)}'),
                        onPressed: submitting
                            ? null
                            : () => _targetCtrl.text = t.toStringAsFixed(0),
                      );
                    }).toList(),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 16),
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

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 33, 72, 243),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.blue.withValues(alpha: 0.6),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : const Text('Create campaign'),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Your campaign starts as a draft. You can submit it for review once you\'re happy with it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _short(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }
}

// Image picker box
class _ImagePicker extends StatelessWidget {
  const _ImagePicker({required this.image, required this.onTap});

  final XFile? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add an image',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(image!.path),
                      fit: BoxFit.cover,
                    ),
                    // Subtle overlay so users see it's tappable
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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