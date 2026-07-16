import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/band.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/menu_items_scope.dart';

/// Invite/share screen: QR code + invite code with copy-link and native share.
class BandInviteScreen extends StatelessWidget {
  const BandInviteScreen({required this.band, super.key});

  final Band band;

  String get _inviteCode => band.inviteCode ?? '';
  String get _joinLink => 'https://flowgroove.app/join?code=$_inviteCode';

  String get _shareText =>
      'Join my band "${band.name}" on FlowGroove!\n\n'
      'Use invite code: $_inviteCode\n\n'
      'Or click the link: $_joinLink';

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _joinLink));
    showAppSnackBar(context, 'Invite link copied to clipboard!');
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: _shareText,
        subject: 'Join my band "${band.name}" on FlowGroove',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = _inviteCode.isNotEmpty;
    // Pushed branch child: title is published for the shell's bottom bar
    // ([← Back] [title] [⋮ Menu]); there is no top app bar.
    return MenuScopePublisher(
      data: MenuScopeData(title: 'Invite to ${band.name}'),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: hasCode
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(MonoPulseSpacing.xl),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            MonoPulseRadius.large,
                          ),
                        ),
                        child: QrImageView(data: _joinLink, size: 220),
                      ),
                      const SizedBox(height: MonoPulseSpacing.xl),
                      Text(
                        'Invite code',
                        style: MonoPulseTypography.bodySmall.copyWith(
                          color: MonoPulseColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: MonoPulseSpacing.xs),
                      SelectableText(
                        _inviteCode,
                        style: MonoPulseTypography.headlineSmall.copyWith(
                          color: MonoPulseColors.accentOrange,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: MonoPulseSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _copyLink(context),
                              icon: const Icon(Icons.link),
                              label: const Text('Copy link'),
                            ),
                          ),
                          const SizedBox(width: MonoPulseSpacing.md),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _share,
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(MonoPulseSpacing.xl),
                    child: Text(
                      'No invite code available for this band.',
                      style: TextStyle(color: MonoPulseColors.textSecondary),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
