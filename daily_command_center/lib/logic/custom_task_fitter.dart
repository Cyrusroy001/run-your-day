import 'package:flutter/foundation.dart';
import '../data/models.dart';

@immutable
class SacrificeOffer {
  final List<Block> drop;
  final int freedMinutes;
  final bool isRecommended;

  const SacrificeOffer({
    required this.drop,
    required this.freedMinutes,
    this.isRecommended = false,
  });

  SacrificeOffer copyWith({bool? isRecommended}) => SacrificeOffer(
        drop: drop,
        freedMinutes: freedMinutes,
        isRecommended: isRecommended ?? this.isRecommended,
      );
}

class CustomTaskFitter {
  /// Slack available via pure compaction: sum of (ideal − min) for every
  /// flexible block (non-anchor, non-custom). No blocks are dropped.
  static int compactionSlack(List<Block> blocks) => blocks
      .where((b) => !b.isAnchor && !b.isCustom && b.idealMinutes > b.minMinutes)
      .fold(0, (sum, b) => sum + (b.idealMinutes - b.minMinutes));

  /// Ranked sacrifice offers that together free at least [neededMinutes].
  ///
  /// Candidates: non-anchor, non-custom, priority ≥ 5 (normal–dropFirst bands).
  /// Sorted highest-priority-number first (drop the most expendable first).
  /// Depth-limited to 8 candidates to keep pair/triple search fast.
  static List<SacrificeOffer> computeOffers(
      List<Block> blocks, int neededMinutes) {
    final candidates = blocks
        .where((b) => !b.isAnchor && !b.isCustom && b.priority >= 5)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final pool = candidates.take(8).toList();
    final offers = <SacrificeOffer>[];

    // Singles
    for (final b in pool) {
      if (b.idealMinutes >= neededMinutes) {
        offers.add(SacrificeOffer(drop: [b], freedMinutes: b.idealMinutes));
      }
    }

    // Pairs
    for (int i = 0; i < pool.length; i++) {
      for (int j = i + 1; j < pool.length; j++) {
        final freed = pool[i].idealMinutes + pool[j].idealMinutes;
        if (freed >= neededMinutes) {
          offers.add(SacrificeOffer(drop: [pool[i], pool[j]], freedMinutes: freed));
        }
      }
    }

    // Triples
    for (int i = 0; i < pool.length; i++) {
      for (int j = i + 1; j < pool.length; j++) {
        for (int k = j + 1; k < pool.length; k++) {
          final freed = pool[i].idealMinutes + pool[j].idealMinutes + pool[k].idealMinutes;
          if (freed >= neededMinutes) {
            offers.add(SacrificeOffer(drop: [pool[i], pool[j], pool[k]], freedMinutes: freed));
          }
        }
      }
    }

    if (offers.isEmpty) return const [];

    // Sort: fewer drops first, then tightest fit (smallest surplus) first.
    offers.sort((a, b) {
      if (a.drop.length != b.drop.length) return a.drop.length - b.drop.length;
      return a.freedMinutes - b.freedMinutes;
    });

    // Deduplicate: same set of block ids → keep first occurrence only.
    final seen = <String>{};
    final deduped = <SacrificeOffer>[];
    for (final o in offers) {
      final key = (o.drop.map((b) => b.id ?? b.label).toList()..sort()).join('|');
      if (seen.add(key)) deduped.add(o);
    }

    return [
      deduped.first.copyWith(isRecommended: true),
      ...deduped.skip(1),
    ];
  }
}
