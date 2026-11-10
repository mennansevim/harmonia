import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../trainer/ui/kit.dart';
import '../app/choir_scope.dart';
import '../app/choir_text.dart';
import '../domain/choir.dart';
import 'invite_code.dart';
import 'online_choir_controller.dart';
import 'online_section.dart';

/// Code (typed or scanned) → choir name → name and part → request. Nothing
/// of the choir opens until the conductor approves.
class JoinChoirScreen extends StatefulWidget {
  const JoinChoirScreen({super.key, this.initialCode, this.scan});
  final String? initialCode;

  /// Opens the camera; returns what was read. Replaced in tests.
  final Future<String?> Function(BuildContext context)? scan;

  @override
  State<JoinChoirScreen> createState() => _JoinChoirScreenState();
}

class _JoinChoirScreenState extends State<JoinChoirScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  String? _choirName;
  String? _foundCode;
  ChoirPart? _part;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _code.text = widget.initialCode ?? '';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _find([String? raw]) async {
    final text = CT.of(context);
    final code = parseInviteCode(raw ?? _code.text);
    if (code == null) {
      toast(context, text.notAnInvite);
      return;
    }
    final online = OnlineChoirScope.read(context);
    setState(() => _busy = true);
    String? name;
    final ok = await runOnline(context, () async {
      name = await online.backend.previewInvite(code);
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _choirName = name;
        _foundCode = code;
        _code.text = formatInviteCode(code);
      }
    });
  }

  Future<void> _scan() async {
    final read = await (widget.scan ?? _openScanner)(context);
    if (read != null && mounted) await _find(read);
  }

  Future<void> _request() async {
    final online = OnlineChoirScope.read(context);
    final text = CT.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await runOnline(
      context,
      () => online.act((b) => b.requestJoin(_foundCode!, _name.text, _part)),
    );
    if (ok) {
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(text.requestSent)));
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final found = _choirName != null;
    return ChoirPage(
      title: found ? _choirName! : text.joinCodeTitle,
      crumb: text.tabLabel,
      subtitle: found ? text.partOptional : text.joinCodeBody,
      bottom: found
          ? BigButton(
              key: const Key('join_request'),
              label: text.sendRequest,
              busy: _busy,
              onPressed: _name.text.trim().isNotEmpty && !_busy
                  ? _request
                  : null,
            )
          : BigButton(
              key: const Key('join_find'),
              label: text.findChoir,
              busy: _busy,
              onPressed: _code.text.trim().isNotEmpty && !_busy ? _find : null,
            ),
      children: [
        if (!found) ...[
          TextField(
            key: const Key('join_code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _find(),
            decoration: choirField(text.inviteCodeField),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('join_scan'),
            onPressed: _busy ? null : _scan,
            icon: const Icon(Ic.scanLine, size: 18),
            label: Text(text.scanQr),
          ),
        ] else ...[
          TextField(
            key: const Key('join_online_name'),
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.yourName),
          ),
          const SizedBox(height: 14),
          PartChips(
            selected: {?_part},
            onTap: (p) => setState(() => _part = _part == p ? null : p),
          ),
        ],
      ],
    );
  }
}

Future<String?> _openScanner(BuildContext context) => Navigator.of(
  context,
).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));

/// The camera, until it reads an invite.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  var _done = false;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(text.scanTitle, style: const TextStyle(fontSize: 15)),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          for (final code in capture.barcodes) {
            final value = code.rawValue;
            if (value != null && parseInviteCode(value) != null) {
              _done = true;
              Navigator.of(context).pop(value);
              return;
            }
          }
        },
      ),
    );
  }
}
