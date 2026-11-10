import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../trainer/ui/kit.dart';
import '../app/choir_scope.dart';
import '../app/choir_screen.dart';
import '../app/choir_text.dart';
import '../domain/choir.dart';
import 'choir_backend.dart';
import 'invite_code.dart';
import 'online_choir_controller.dart';
import 'online_section.dart';

/// One online choir: the roster by part. The conductor also sees join
/// requests, invites and member controls; singers see who sings with them.
class OnlineChoirScreen extends StatefulWidget {
  const OnlineChoirScreen({super.key, required this.choirId});
  final String choirId;
  @override
  State<OnlineChoirScreen> createState() => _OnlineChoirScreenState();
}

class _OnlineChoirScreenState extends State<OnlineChoirScreen> {
  List<ChoirMember> _members = const [];
  List<JoinRequest> _requests = const [];
  DriveStatus? _drive;
  var _loading = true;
  var _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final online = OnlineChoirScope.read(context);
    final conducts = online.choir(widget.choirId)?.iConduct ?? false;
    await runOnline(context, () async {
      final members = await online.backend.members(widget.choirId);
      final requests = conducts
          ? await online.backend.joinRequests(widget.choirId)
          : const <JoinRequest>[];
      final drive = await online.backend.driveStatus(widget.choirId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _requests = requests;
        _drive = drive;
      });
    });
    if (mounted) setState(() => _loading = false);
  }

  /// A change, then both the roster and the tab's list reload.
  Future<void> _change(Future<void> Function(ChoirBackend b) call) async {
    final online = OnlineChoirScope.read(context);
    if (await runOnline(context, () => online.act(call))) await _load();
  }

  Future<void> _connectDrive() async {
    final online = OnlineChoirScope.read(context);
    Uri? url;
    final ok = await runOnline(context, () async {
      url = await online.backend.startDriveConnect(widget.choirId);
    });
    if (ok) await online.openUrl(url!);
  }

  /// Mirrors the choir onto this device, then opens the work screens.
  Future<void> _openWork() async {
    final text = CT.of(context);
    if (_drive?.connected != true) {
      toast(context, text.driveWaiting);
      return;
    }
    final store = ChoirScope.read(context).store;
    final nav = Navigator.of(context);
    setState(() => _opening = true);
    final ok = await runOnline(context, () => store.syncOnline(widget.choirId));
    if (!mounted) return;
    setState(() => _opening = false);
    if (ok) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ChoirScreen(choirId: widget.choirId),
        ),
      );
    }
  }

  Future<bool> _confirm(String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(CT.of(context).cancel),
            ),
            TextButton(
              key: const Key('confirm_yes'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final online = OnlineChoirScope.of(context);
    final text = CT.of(context);
    final c = online.choir(widget.choirId);
    if (c == null) {
      return ChoirPage(
        title: text.tabLabel,
        crumb: text.tabLabel,
        children: [
          if (online.loading || _loading)
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final conducts = c.iConduct;
    final singers = [
      for (final m in _members)
        if (m.isSinger) m,
    ];
    final groups = <ChoirPart?, List<ChoirMember>>{
      for (final p in [...ChoirPart.values, null])
        p: [
          for (final m in singers)
            if (m.part == p) m,
        ],
    }..removeWhere((_, list) => list.isEmpty);

    return ChoirPage(
      title: c.choir.name,
      crumb: text.tabLabel,
      subtitle: text.membersCount(_members.length),
      trailing: TiltTag(
        conducts
            ? text.conductorTag
            : c.me.part == null
            ? text.noPart
            : text.partName(c.me.part!),
      ),
      children: [
        if (!conducts && c.me.leadsPart)
          AppCard(
            color: TC.primarySoft,
            child: Text(
              '${text.youLead}. ${text.sectionLeaderHint}',
              style: TT.body,
            ),
          ),
        if (conducts) ...[
          if (_requests.isNotEmpty) ...[
            Caption(text.caps(text.requestsTitle)),
            for (final r in _requests)
              ChoirRow(
                key: Key('request_${r.id}'),
                icon: Ic.userPlus,
                title: r.displayName,
                subtitle: text.wantsPart(r.wantedPart),
                onTap: () async {
                  final decision = await showTrainerSheet<_Decision>(
                    context,
                    (_) => _DecideSheet(request: r),
                  );
                  if (decision == null) return;
                  await _change(
                    (b) => b.decideJoin(
                      r.id,
                      approve: decision.approve,
                      part: decision.part,
                    ),
                  );
                },
              ),
          ],
          const SizedBox(height: 8),
          ChoirRow(
            key: const Key('open_invite'),
            icon: Ic.qrCode,
            title: text.inviteTitle,
            subtitle: text.inviteBody,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    InviteScreen(choirId: c.id, choirName: c.choir.name),
              ),
            ),
          ),
        ],
        for (final entry in groups.entries) ...[
          Caption(
            text.caps(
              '${entry.key == null ? text.noPart : text.partName(entry.key!)} · ${entry.value.length}',
            ),
          ),
          for (final m in entry.value)
            ChoirRow(
              key: Key('member_${m.userId}'),
              icon: m.leadsPart ? Ic.crown : Ic.user,
              title: m.displayName,
              subtitle: m.leadsPart ? text.sectionLeader : null,
              onTap: conducts
                  ? () => showTrainerSheet<void>(
                      context,
                      (_) => _MemberSheet(
                        member: m,
                        onPart: (p) =>
                            _change((b) => b.setMemberPart(c.id, m.userId, p)),
                        onLead: (v) => _change(
                          (b) => b.setSectionLeader(c.id, m.userId, v),
                        ),
                        onRemove: () async {
                          if (await _confirm(
                            text.removeConfirm(m.displayName),
                            text.removeFromChoir,
                          )) {
                            await _change(
                              (b) => b.removeMember(c.id, m.userId),
                            );
                          }
                        },
                      ),
                    )
                  : null,
            ),
        ],
        const SizedBox(height: 12),
        if (conducts)
          ChoirRow(
            key: const Key('drive_row'),
            icon: Ic.hardDrive,
            title: text.driveTitle,
            subtitle: _drive?.connected == true
                ? text.driveConnected(_drive?.email)
                : text.driveConnectHint,
            trailing: _drive?.connected == true
                ? const Icon(Ic.check, color: TC.primary)
                : null,
            onTap: _drive?.connected == true ? null : _connectDrive,
          ),
        if (conducts && _drive?.connected != true && !_loading)
          TextLink(text.driveCheckAgain, onTap: _load),
        if (!conducts && _drive?.connected != true && !_loading)
          AppCard(
            child: Text(
              text.driveWaiting,
              style: TT.small.copyWith(color: TC.muted),
            ),
          ),
        ChoirRow(
          key: const Key('open_online_work'),
          color: TC.sun,
          icon: Ic.music2,
          title: text.openOnlineWork,
          subtitle: text.openOnlineWorkSub,
          trailing: _opening
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _opening ? null : _openWork,
        ),
        const SizedBox(height: 8),
        TextLink(
          conducts ? text.deleteChoir : text.leaveOnline,
          onTap: () async {
            final nav = Navigator.of(context);
            final ok = await _confirm(
              conducts ? text.deleteConfirm(c.choir.name) : text.leaveConfirm,
              conducts ? text.deleteChoir : text.leaveOnline,
            );
            if (!ok || !context.mounted) return;
            final done = await runOnline(
              context,
              () => online.act(
                (b) => conducts
                    ? b.deleteChoir(c.id)
                    : b.removeMember(c.id, c.me.userId),
              ),
            );
            if (done) nav.pop();
          },
        ),
      ],
    );
  }
}

class _Decision {
  const _Decision(this.approve, this.part);
  final bool approve;
  final ChoirPart? part;
}

class _DecideSheet extends StatefulWidget {
  const _DecideSheet({required this.request});
  final JoinRequest request;
  @override
  State<_DecideSheet> createState() => _DecideSheetState();
}

class _DecideSheetState extends State<_DecideSheet> {
  late ChoirPart? _part = widget.request.wantedPart;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.request.displayName, style: TT.h3),
        const SizedBox(height: 4),
        Text(
          text.wantsPart(widget.request.wantedPart),
          style: TT.body.copyWith(color: TC.muted),
        ),
        const SizedBox(height: 14),
        Text(text.approvePartHint, style: TT.title),
        const SizedBox(height: 8),
        PartChips(selected: {?_part}, onTap: (p) => setState(() => _part = p)),
        const SizedBox(height: 16),
        BigButton(
          key: const Key('decide_approve'),
          label: text.approve,
          icon: Ic.check,
          onPressed: _part == null
              ? null
              : () => Navigator.pop(context, _Decision(true, _part)),
        ),
        SoftButton(
          key: const Key('decide_decline'),
          label: text.decline,
          onPressed: () => Navigator.pop(context, const _Decision(false, null)),
        ),
      ],
    );
  }
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({
    required this.member,
    required this.onPart,
    required this.onLead,
    required this.onRemove,
  });
  final ChoirMember member;
  final Future<void> Function(ChoirPart) onPart;
  final Future<void> Function(bool) onLead;
  final Future<void> Function() onRemove;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late ChoirPart? _part = widget.member.part;
  late bool _leads = widget.member.leadsPart;

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.member.displayName, style: TT.h3),
        const SizedBox(height: 14),
        Text(text.changePart, style: TT.title),
        const SizedBox(height: 8),
        PartChips(
          selected: {?_part},
          onTap: (p) async {
            if (p == _part) return;
            setState(() {
              _part = p;
              _leads = false;
            });
            await widget.onPart(p);
          },
        ),
        const SizedBox(height: 10),
        // The sheet paints its own colour; the tile needs a Material of its own.
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const Key('member_leader'),
            contentPadding: EdgeInsets.zero,
            title: Text(text.sectionLeader, style: TT.title),
            subtitle: Text(text.sectionLeaderHint, style: TT.small),
            value: _leads,
            onChanged: _part == null
                ? null
                : (v) async {
                    setState(() => _leads = v);
                    await widget.onLead(v);
                  },
          ),
        ),
        const SizedBox(height: 6),
        SoftButton(
          key: const Key('member_remove'),
          label: text.removeFromChoir,
          onPressed: () async {
            Navigator.pop(context);
            await widget.onRemove();
          },
        ),
      ],
    );
  }
}

/// The conductor's invite: a code to read out, the same code as a QR, and
/// share/revoke. Makes a code on first open.
class InviteScreen extends StatefulWidget {
  const InviteScreen({
    super.key,
    required this.choirId,
    required this.choirName,
  });
  final String choirId;
  final String choirName;
  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  Invite? _invite;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool fresh = false}) async {
    final backend = OnlineChoirScope.read(context).backend;
    setState(() => _loading = true);
    final old = fresh ? _invite : null;
    await runOnline(context, () async {
      // A new code replaces the shown one, so only one code is in use.
      if (old != null) await backend.revokeInvite(old.code);
      var list = await backend.invites(widget.choirId);
      final now = DateTime.now().toUtc();
      Invite? current = fresh
          ? null
          : list.where((i) => i.check(now) == InviteCheck.ok).firstOrNull;
      if (current == null) {
        await backend.createInvite(widget.choirId);
        list = await backend.invites(widget.choirId);
        current = list.where((i) => i.check(now) == InviteCheck.ok).firstOrNull;
      }
      if (mounted) setState(() => _invite = current);
    });
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _revoke() async {
    final backend = OnlineChoirScope.read(context).backend;
    final code = _invite!.code;
    final ok = await runOnline(context, () => backend.revokeInvite(code));
    if (ok && mounted) setState(() => _invite = null);
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final invite = _invite;
    return ChoirPage(
      title: text.inviteTitle,
      crumb: widget.choirName,
      subtitle: text.inviteBody,
      bottom: invite == null
          ? BigButton(
              key: const Key('invite_new'),
              label: text.newCode,
              busy: _loading,
              onPressed: _loading ? null : () => _load(fresh: true),
            )
          : Builder(
              builder: (button) => BigButton(
                key: const Key('invite_share'),
                label: text.shareCode,
                icon: Ic.share2,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text:
                        '${text.shareMessage(widget.choirName, formatInviteCode(invite.code))}\n${inviteLink(invite.code)}',
                    sharePositionOrigin: shareOrigin(button),
                  ),
                ),
              ),
            ),
      children: [
        if (invite == null)
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Text(text.noActiveCode, style: TT.body)
        else ...[
          Center(
            child: Semantics(
              label: text.scanQr,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  key: const Key('invite_qr'),
                  data: inviteLink(invite.code),
                  size: 220,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: SelectableText(
              formatInviteCode(invite.code),
              key: const Key('invite_code'),
              style: TT.display.copyWith(letterSpacing: 4),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${text.inviteExpires(invite.expiresAt.toLocal())} · ${text.inviteUses(invite.uses, invite.maxUses)}',
              style: TT.small.copyWith(color: TC.muted),
            ),
          ),
          const SizedBox(height: 16),
          TextLink(text.newCode, onTap: () => _load(fresh: true)),
          TextLink(text.revokeCode, onTap: _revoke),
        ],
      ],
    );
  }
}
