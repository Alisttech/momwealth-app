import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Discounts from MOM's partner vendors. Offers are added by MOM (Firestore `vendorOffers`).
class VendorOffersScreen extends StatelessWidget {
  const VendorOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final offers = context.watch<Session>().offers;
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor discounts')),
      body: PageBody(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            Icon(Icons.local_offer_outlined, color: Colors.white, size: 30),
            SizedBox(width: 14),
            Expanded(
              child: Text('As a MOM Wealth member you get special prices from vendors we partner with. Show the offer or use the code at checkout.',
                  style: TextStyle(color: Colors.white, height: 1.45)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (offers.isEmpty)
          const EmptyCard('New member deals are coming soon. We\'ll notify you as soon as our first partner offers go live.')
        else
          for (final o in offers) ...[_OfferCard(o), const SizedBox(height: 10)],
      ]),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard(this.o);
  final VendorOffer o;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Initials(o.vendor, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.vendor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (o.category.isNotEmpty) Text(o.category, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text(o.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.green)),
          if (o.details.isNotEmpty) ...[const SizedBox(height: 4), Text(o.details, style: const TextStyle(color: AppColors.inkSoft, height: 1.4))],
          if (o.code.isNotEmpty || o.link.isNotEmpty) const SizedBox(height: 12),
          Row(children: [
            if (o.code.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: o.code));
                    toast(context, 'Code copied');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(o.code),
                ),
              ),
            if (o.code.isNotEmpty && o.link.isNotEmpty) const SizedBox(width: 10),
            if (o.link.startsWith('http'))
              Expanded(
                child: FilledButton(
                  onPressed: () => launchUrl(Uri.parse(o.link), mode: LaunchMode.externalApplication),
                  child: const Text('Visit vendor'),
                ),
              ),
          ]),
        ]),
      );
}
