import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/api_error.dart';
import '../../providers/data/data_providers.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/error_provider.dart';
import '../../models/band.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/custom_app_bar.dart';
import '../../theme/mono_pulse_theme.dart';

/// Screen for creating or editing a band with comprehensive error handling.
class CreateBandScreen extends ConsumerStatefulWidget {
  final Band? band;

  const CreateBandScreen({super.key, this.band});

  @override
  ConsumerState<CreateBandScreen> createState() => _CreateBandScreenState();
}

class _CreateBandScreenState extends ConsumerState<CreateBandScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  ApiError? _currentError;
  bool _hasUnsavedChanges = false;

  bool get _isEditing => widget.band != null;

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.band!.name;
      _descriptionController.text = widget.band!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Handles an error by updating state.
  void _handleError(ApiError error) {
    setState(() {
      _currentError = error;
    });
    ref.read(errorNotifierProvider.notifier).handleError(error);
  }

  /// Generates a unique invite code with collision detection.
  Future<String> _generateUniqueInviteCode() async {
    final service = ref.read(firestoreProvider);

    String code;
    bool isTaken;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      code = Band.generateUniqueInviteCode();
      isTaken = await service.isInviteCodeTaken(code);
      attempts++;

      if (attempts > maxAttempts) {
        throw ApiError.unknown(
          message: 'Failed to generate unique invite code. Please try again.',
        );
      }
    } while (isTaken);

    return code;
  }

  Future<void> _saveBand() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isLoading = true;
      _currentError = null;
    });

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) {
        _handleError(ApiError.auth(message: 'Please login to create a band.'));
        return;
      }

      final service = ref.read(firestoreProvider);

      // Generate unique invite code for new bands
      final inviteCode = _isEditing
          ? widget.band!.inviteCode
          : await _generateUniqueInviteCode();

      final band = Band(
        id: _isEditing ? widget.band!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        createdBy: _isEditing ? widget.band!.createdBy : user.uid,
        members: _isEditing
            ? widget.band!.members
            : [
                BandMember(
                  uid: user.uid,
                  role: BandMember.roleAdmin,
                  displayName: user.displayName,
                  email: user.email,
                ),
              ],
        inviteCode: inviteCode,
        createdAt: _isEditing ? widget.band!.createdAt : DateTime.now(),
      );

      // Save to global collection (for cross-user access)
      await service.saveBandToGlobal(band);

      // Save to user's collection (for quick access and listing)
      await service.saveBand(band, uid: user.uid);

      if (mounted) {
        // Show invite code dialog for new bands
        if (!_isEditing) {
          _showInviteCodeDialog(band.inviteCode!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Band "${band.name}" ${_isEditing ? 'updated' : 'created'}!',
              ),
            ),
          );
          // Clear unsaved changes flag after successful save
          setState(() => _hasUnsavedChanges = false);
          Navigator.pop(context);
        }
      }
    } on ApiError catch (e) {
      _handleError(e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e, stackTrace) {
      final error = ApiError.fromException(e, stackTrace: stackTrace);
      _handleError(error);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showDiscardChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to discard them?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Shows a dialog with the invite code and a copy button.
  void _showInviteCodeDialog(String inviteCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Band Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this invite code with your bandmates:',
              style: MonoPulseTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(MonoPulseSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(MonoPulseRadius.small),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      inviteCode,
                      style: MonoPulseTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // Already popped

        if (_hasUnsavedChanges) {
          final confirm = await _showDiscardChangesDialog();
          if (confirm && context.mounted) {
            if (context.mounted) {
              Navigator.pop(context); // Allow pop
            }
          }
        }
      },
      child: Scaffold(
        appBar: CustomAppBar.build(
          context,
          title: _isEditing ? 'Edit Band' : 'Create Band',
          menuItems: [
            PopupMenuItem<void>(
              onTap: _saveBand,
              child: const Text('Save Band'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit band details' : 'Create a new band',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditing
                      ? 'Update band information'
                      : 'Invite your bandmates',
                  style: const TextStyle(color: MonoPulseColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Error banner
                if (_currentError != null) ...[
                  ErrorBanner.banner(
                    message:
                        _currentError?.message ??
                        'An unexpected error occurred',
                    onRetry: _saveBand,
                  ),
                  const SizedBox(height: 24),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Band Name *',
                    prefixIcon: Icon(Icons.groups),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _markAsChanged(),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _markAsChanged(),
                  onFieldSubmitted: (_) => _saveBand(),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveBand,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: MonoPulseColors.textPrimary,
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Create Band'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
