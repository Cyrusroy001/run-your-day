import '../data/models.dart';

// Resolve block time strings to 24h decimals.
// Walks forward through the day — never moves backward — to correctly
// disambiguate AM vs PM (e.g. "8:30" after "11:15" → 20.5, not 8.5).
List<double> buildTimes(List<Block> blocks) {
  double prev = 0;
  return blocks.map((b) {
    final parts = b.time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final candidates = h == 12 ? [12.0 + m / 60] : [h + m / 60, h + 12.0 + m / 60];
    candidates.sort();
    double val = candidates.last;
    for (final c in candidates) {
      if (c >= prev - 0.001) { val = c; break; }
    }
    prev = val;
    return val;
  }).toList();
}

double nowDecimal() {
  final n = DateTime.now();
  return n.hour + n.minute / 60;
}
