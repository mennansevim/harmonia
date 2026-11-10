import 'package:flutter/material.dart';

import '../../trainer/ui/kit.dart';
import '../app/choir_scope.dart';
import '../app/choir_text.dart';
import '../domain/choir.dart';
import 'choir_backend.dart';
import 'online_choir_controller.dart';
import 'online_choir_screen.dart';
import 'online_join.dart';

/// Runs a server call; shows the refusal as a toast. True when it worked.
Future<bool> runOnline(
  BuildContext context,
  Future<void> Function() call,
) async {
  final text = CT.of(context);
  try {
    await call();
    return true;
  } on ChoirBackendException catch (e) {
    if (context.mounted) toast(context, text.backendProblem(e.problem));
    return false;
  }
}

/// Top of the Koro tab when the build has a server: sign-in, the person's
/// choirs, waiting requests, join and set-up.
class OnlineChoirSection extends StatelessWidget {
  const OnlineChoirSection({super.key});

  @override
  Widget build(BuildContext context) {
    final online = OnlineChoirScope.of(context);
    final text = CT.of(context);
    if (!online.signedIn) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text.onlineTitle, style: TT.h3),
              const SizedBox(height: 6),
              Text(text.onlineBody, style: TT.body.copyWith(color: TC.muted)),
              const SizedBox(height: 14),
              BigButton(
                key: const Key('online_sign_in'),
                label: text.signIn,
                icon: Ic.mail,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
                ),
              ),
            ],
          ),
        ),
      );
    }
    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (online.problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              border: TC.peach,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text.backendProblem(online.problem!), style: TT.body),
                  TextLink(text.retry, onTap: online.refresh),
                ],
              ),
            ),
          ),
        Caption(text.caps(text.myOnlineChoirs)),
        for (final c in online.choirs)
          ChoirRow(
            key: Key('online_choir_${c.id}'),
            icon: Ic.users,
            title: c.choir.name,
            subtitle: _role(text, c.me),
            onTap: () => open(OnlineChoirScreen(choirId: c.id)),
          ),
        for (final r in online.waiting)
          ChoirRow(
            key: Key('online_request_${r.id}'),
            icon: Ic.hourglass,
            title: r.choirName ?? '',
            subtitle: text.waitingApproval,
            trailing: TextButton(
              onPressed: () => runOnline(
                context,
                () => online.act((b) => b.cancelJoinRequest(r.id)),
              ),
              child: Text(text.cancelRequest),
            ),
          ),
        if (online.loading && online.choirs.isEmpty && online.waiting.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 6),
        BigButton(
          key: const Key('online_join'),
          label: text.joinWithCode,
          icon: Ic.qrCode,
          onPressed: () => open(const JoinChoirScreen()),
        ),
        TextLink(
          text.createOnline,
          onTap: () async {
            final id = await showTrainerSheet<String>(
              context,
              (_) => const _CreateOnlineSheet(),
            );
            if (id != null && context.mounted) {
              toast(context, text.created);
              open(OnlineChoirScreen(choirId: id));
            }
          },
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                text.signedInAs(online.backend.email ?? ''),
                style: TT.small.copyWith(color: TC.muted),
              ),
            ),
            TextButton(
              key: const Key('online_sign_out'),
              onPressed: () => runOnline(context, online.signOut),
              child: Text(text.signOut),
            ),
          ],
        ),
      ],
    );
  }
}

String _role(CT text, ChoirMember me) {
  if (me.isConductor) return text.conductorTag;
  final part = me.part == null ? text.noPart : text.partName(me.part!);
  return me.leadsPart ? '$part · ${text.sectionLeader}' : part;
}

class _CreateOnlineSheet extends StatefulWidget {
  const _CreateOnlineSheet();
  @override
  State<_CreateOnlineSheet> createState() => _CreateOnlineSheetState();
}

class _CreateOnlineSheetState extends State<_CreateOnlineSheet> {
  final _choir = TextEditingController();
  final _name = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _choir.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final online = OnlineChoirScope.read(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    String? id;
    final ok = await runOnline(context, () async {
      id = await online.act((b) => b.createChoir(_choir.text, _name.text));
    });
    if (ok) {
      nav.pop(id);
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = CT.of(context);
    final ready = _choir.text.trim().isNotEmpty && _name.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.createOnline, style: TT.h3),
          const SizedBox(height: 14),
          TextField(
            key: const Key('online_choir_name'),
            controller: _choir,
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.choirName),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('online_my_name'),
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.yourName),
          ),
          const SizedBox(height: 16),
          BigButton(
            key: const Key('online_create_confirm'),
            label: text.create,
            busy: _busy,
            onPressed: ready && !_busy ? _create : null,
          ),
        ],
      ),
    );
  }
}

/// Email → 6-digit code → signed in. Apple and Google sign-in join once the
/// store/cloud accounts exist (ADR-041 Faz 0).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  var _sent = false;
  var _busy = false;

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _go(Future<void> Function() call, VoidCallback done) async {
    setState(() => _busy = true);
    final ok = await runOnline(context, call);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) done();
  }

  @override
  Widget build(BuildContext context) {
    final online = OnlineChoirScope.of(context);
    final text = CT.of(context);
    final email = _email.text.trim();
    return ChoirPage(
      title: text.signInTitle,
      crumb: text.tabLabel,
      subtitle: _sent ? text.codeSentTo(email) : text.signInBody,
      bottom: _sent
          ? BigButton(
              key: const Key('sign_in_verify'),
              label: text.verify,
              busy: _busy,
              onPressed: _code.text.trim().length == 6 && !_busy
                  ? () => _go(
                      () => online.backend.verifyEmailCode(email, _code.text),
                      () => Navigator.of(context).pop(),
                    )
                  : null,
            )
          : BigButton(
              key: const Key('sign_in_send'),
              label: text.sendCode,
              busy: _busy,
              onPressed: _emailShape.hasMatch(email) && !_busy
                  ? () => _go(
                      () => online.backend.sendEmailCode(email),
                      () => setState(() => _sent = true),
                    )
                  : null,
            ),
      children: [
        if (!_sent)
          TextField(
            key: const Key('sign_in_email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.emailField),
          )
        else ...[
          TextField(
            key: const Key('sign_in_code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            onChanged: (_) => setState(() {}),
            decoration: choirField(text.codeField),
          ),
          TextLink(
            text.otherEmail,
            onTap: () => setState(() {
              _sent = false;
              _code.clear();
            }),
          ),
        ],
      ],
    );
  }
}
