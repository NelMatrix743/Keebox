class LocalUnlockState {
  const LocalUnlockState({
    this.isSubmitting = false,
    this.isUnlocked = false,
    this.requiresLogin = false,
    this.entryRevision = 0,
    this.errorMessage,
  });

  final bool isSubmitting;
  final bool isUnlocked;
  final bool requiresLogin;
  final int entryRevision;
  final String? errorMessage;
}
