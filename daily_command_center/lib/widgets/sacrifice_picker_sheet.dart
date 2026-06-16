import 'package:flutter/material.dart';
import '../logic/custom_task_fitter.dart';
import '../theme/app_palette.dart';

void showSacrificePickerSheet(
  BuildContext context, {
  required List<SacrificeOffer> offers,
  required String taskLabel,
  required void Function(SacrificeOffer offer) onConfirm,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SacrificePickerSheet(
      offers: offers,
      taskLabel: taskLabel,
      onConfirm: onConfirm,
    ),
  );
}

class _SacrificePickerSheet extends StatelessWidget {
  final List<SacrificeOffer> offers;
  final String taskLabel;
  final void Function(SacrificeOffer) onConfirm;

  const _SacrificePickerSheet({
    required this.offers,
    required this.taskLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: c.raise2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: c.dim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Make room for', style: TextStyle(
                    fontSize: 12, color: c.dim,
                    fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('"$taskLabel"', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: c.salt),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('Drop one of these to fit it in:',
                      style: TextStyle(fontSize: 13, color: c.dim)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: c.line, height: 1),
            // Offers list
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _OfferTile(
                  offer: offers[i],
                  palette: c,
                  onConfirm: () {
                    Navigator.of(context).pop();
                    onConfirm(offers[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final SacrificeOffer offer;
  final AppPalette palette;
  final VoidCallback onConfirm;

  const _OfferTile({
    required this.offer,
    required this.palette,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final c = palette;
    final dropLabels = offer.drop.map((b) => b.label).toList();

    return Container(
      decoration: BoxDecoration(
        color: c.raise,
        borderRadius: BorderRadius.circular(12),
        border: offer.isRecommended
            ? Border.all(color: c.jammy.withValues(alpha: 0.6), width: 1.5)
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (offer.isRecommended) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.jammyDim,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Recommended', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: c.jammyText, letterSpacing: 0.3)),
              ),
              const SizedBox(width: 8),
            ],
            Text('Frees ${offer.freedMinutes} min',
                style: TextStyle(fontSize: 12, color: c.dim)),
          ]),
          const SizedBox(height: 8),
          // Drop labels
          Wrap(
            spacing: 6, runSpacing: 6,
            children: dropLabels.map((label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.raise2,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: c.salt)),
            )).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: offer.isRecommended ? c.vine : c.raise2,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Drop it', style: TextStyle(
                color: offer.isRecommended ? c.salt : c.dim,
                fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
