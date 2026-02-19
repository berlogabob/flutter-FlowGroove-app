import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';
import '../../models/band.dart';

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

  bool get _isEditing => widget.band != null;

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
        throw Exception('Failed to generate unique invite code after $maxAttempts attempts');
      }
    } while (isTaken);

    return code;
  }

  Future<void> _saveBand() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
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
      await service.saveBand(band, user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Band "${band.name}" ${_isEditing ? 'updated' : 'created'}!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Band' : 'Create Band')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Band Name *',
                  prefixIcon: Icon(Icons.groups),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                textInputAction: TextInputAction.done,
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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isEditing ? 'Save Changes' : 'Create Band'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
