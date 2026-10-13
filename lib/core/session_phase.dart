/// Lifecycle of one caption session.
///
/// Pause is intentionally absent. Neither planned engine promises pause
/// and resume, so the user stops a session and starts it again.
enum SessionPhase {
  idle,
  initializing,
  listening,
  processing,
  stopping,
  completed,
  recoverableError,
  unavailable,
}

extension SessionPhaseActivity on SessionPhase {
  bool get isActive {
    switch (this) {
      case SessionPhase.initializing:
      case SessionPhase.listening:
      case SessionPhase.processing:
      case SessionPhase.stopping:
        return true;
      case SessionPhase.idle:
      case SessionPhase.completed:
      case SessionPhase.recoverableError:
      case SessionPhase.unavailable:
        return false;
    }
  }
}
