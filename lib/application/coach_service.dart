import 'dart:async';

import '../domain/coach/coach_contract.dart';

/// Server-side gateway (not implemented in the app; the mobile client holds
/// no API key). Returns the model's parsed JSON reply.
abstract interface class CoachGateway {
  Future<Object?> complete(CoachInput input);
}

enum CoachSource { ai, fallback }

class CoachMessage {
  const CoachMessage({
    required this.text,
    required this.source,
    this.nextExerciseId,
    this.rejection,
  });
  final String text;
  final CoachSource source;
  final String? nextExerciseId;
  final CoachRejection? rejection;
}

/// Gateway call with timeout + strict validation; every failure returns the
/// deterministic [fallback] text. AI output is labelled and never alters a
/// score or impersonates an educator.
class CoachService {
  CoachService({this.gateway, this.timeout = const Duration(seconds: 6)});
  final CoachGateway? gateway;
  final Duration timeout;

  Future<CoachMessage> explain(
    CoachInput input, {
    required String fallback,
  }) async {
    final g = gateway;
    if (g == null) {
      return CoachMessage(text: fallback, source: CoachSource.fallback);
    }
    try {
      final raw = await g.complete(input).timeout(timeout);
      final (reply, rejection) = CoachReplyValidator.validate(raw, input);
      if (reply == null) {
        return CoachMessage(
          text: fallback,
          source: CoachSource.fallback,
          rejection: rejection,
        );
      }
      return CoachMessage(
        text: reply.summary,
        source: CoachSource.ai,
        nextExerciseId: reply.nextExerciseId,
      );
    } catch (_) {
      return CoachMessage(text: fallback, source: CoachSource.fallback);
    }
  }
}
