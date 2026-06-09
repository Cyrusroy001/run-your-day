enum PriorityLevel {
  protect('Protect', 2),
  normal('Normal', 4),
  dropFirst('Drop first', 7);

  final String label;
  final int _rep;
  const PriorityLevel(this.label, this._rep);

  int toPriority() => _rep;

  static PriorityLevel fromPriority(int p) {
    if (p <= 2) return PriorityLevel.protect;
    if (p <= 5) return PriorityLevel.normal;
    return PriorityLevel.dropFirst;
  }
}
