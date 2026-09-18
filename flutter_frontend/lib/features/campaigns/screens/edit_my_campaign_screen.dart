import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/edit_campaign_bloc.dart';
import '../bloc/edit_campaign_event.dart';
import '../bloc/edit_campaign_state.dart';
import '../data/models/campaign.dart';

class EditMyCampaignScreen extends StatelessWidget {
  const EditMyCampaignScreen({super.key, required this.campaignId});

  final int campaignId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EditCampaignBloc()
        ..add(EditCampaignStarted(campaignId)),
      child: const _EditCampaignView(),
    );
  }
}

class _EditCampaignView extends StatelessWidget {
  const _EditCampaignView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Campaign')),
      body: BlocBuilder<EditCampaignBloc, EditCampaignState>(
        builder: (context, state) {
          return switch (state) {
            EditCampaignInitial() || EditCampaignLoading() =>
              const Center(child: CircularProgressIndicator()),
            EditCampaignFailure() =>
              _ErrorView(message: state.message),
            EditCampaignReady() => _Form(campaign: state.campaign),
            EditCampaignSuccess() => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

// The form itself
class _Form extends StatefulWidget {
  const _Form({required this.campaign});

  final Campaign campaign;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _targetCtrl;
  XFile? _image;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _titleCtrl = TextEditingController(text: c.title);
    _descCtrl = TextEditingController(text: c.description);
    _targetCtrl = TextEditingController(
      text: c.targetAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  /// Which fields can be edited given the campaign's current status.
  /// Mirrors Campaign.get_editable_fields on the backend.
  Set<String> get _editable {
    switch (widget.campaign.status) {
      case 'DRAFT':
        return {'title', 'description', 'target_amount', 'image'};
      case 'ACTIVE':
        return {'target_amount'};
      default:
        return {};
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (file != null) setState(() => _image = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
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
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final editable = _editable;

    context.read<EditCampaignBloc>().add(
          EditCampaignSubmitted(
            id: widget.campaign.id,
            title: editable.contains('title') ? _titleCtrl.text.trim() : null,
            description:
                editable.contains('description') ? _descCtrl.text.trim() : null,
            targetAmount: editable.contains('target_amount')
                ? double.parse(_targetCtrl.text.trim())
                : null,
            image: editable.contains('image') ? _image : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editable = _editable;

    return BlocListener<EditCampaignBloc, EditCampaignState>(
      listenWhen: (_, curr) =>
          curr is EditCampaignSuccess || curr is EditCampaignFailure,
      listener: (context, state) {
        if (state is EditCampaignSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Campaign updated.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is EditCampaignFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: BlocBuilder<EditCampaignBloc, EditCampaignState>(
        builder: (context, state) {
          final submitting =
              state is EditCampaignReady && state.submitting;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (editable.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Campaigns in ${widget.campaign.statusLabel} '
                        'status cannot be edited.',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),

                  if (editable.contains('image')) ...[
                    _ImageBox(
                      campaign: widget.campaign,
                      pickedImage: _image,
                      onTap: submitting ? null : _showImageOptions,
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (editable.contains('title'))
                    TextFormField(
                      controller: _titleCtrl,
                      enabled: !submitting,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Campaign title',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                  if (editable.contains('title'))
                    const SizedBox(height: 8),

                  if (editable.contains('description'))
                    TextFormField(
                      controller: _descCtrl,
                      enabled: !submitting,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Description is required';
                        }
                        return null;
                      },
                    ),
                  if (editable.contains('description'))
                    const SizedBox(height: 20),

                  if (editable.contains('target_amount'))
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
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Target amount is required';
                        }
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null) return 'Invalid number';
                        if (parsed < 100) return 'Minimum 100 ETB';
                        return null;
                      },
                    ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed:
                        submitting || editable.isEmpty ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Image box

class _ImageBox extends StatelessWidget {
  const _ImageBox({
    required this.campaign,
    required this.pickedImage,
    required this.onTap,
  });

  final Campaign campaign;
  final XFile? pickedImage;
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pickedImage != null)
                Image.file(File(pickedImage!.path), fit: BoxFit.cover)
              else if (campaign.imageUrl != null &&
                  campaign.imageUrl!.isNotEmpty)
                Image.network(campaign.imageUrl!, fit: BoxFit.cover)
              else
                Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 44,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 14, color: Colors.white),
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