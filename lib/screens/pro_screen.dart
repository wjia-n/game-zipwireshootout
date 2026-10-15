import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../theme/game_config.dart';
import '../services/audio_service.dart';

class ProScreen extends StatefulWidget {
  final GameConfig config;
  final ZipwireshootoutAudio audio;
  const ProScreen({super.key, required this.config, required this.audio});
  @override State<ProScreen> createState() => _ProScreenState();
}
class _ProScreenState extends State<ProScreen> {
  bool isPro = false;
  @override void initState() { super.initState(); _checkPro(); }
  Future<void> _checkPro() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      return;
    }
    await InAppPurchase.instance.restorePurchases();
    // simplified: real apps verify purchaseDetails stream
  }
  Future<void> _buy(String productId) async {
    final resp = await InAppPurchase.instance.queryProductDetails({productId});
    if (resp.productDetails.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not available yet — coming soon!')));
      return;
    }
    final param = PurchaseParam(productDetails: resp.productDetails.first);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }
  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(backgroundColor: c.darkColor,
      appBar: AppBar(title: const Text('Go Pro'), backgroundColor: c.primaryColor, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('⭐ FREE vs PRO', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _row('Full game', 'Full game + exclusive themes'),
        _row('3 target speeds', 'All speeds + slow-mo mode'),
        _row('Basic crosshair', '8 pro crosshairs'),
        _row('Standard SFX', 'Premium sound pack'),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: () { widget.audio.click(); _buy(c.proId); },
          child: Text('UNLOCK PRO — ${c.proId}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () { widget.audio.click(); _buy(c.coffeeId); },
          child: Text('☕ Buy me a coffee (${c.coffeeId})', style: const TextStyle(color: Colors.white))),
        OutlinedButton(onPressed: () { widget.audio.click(); _buy(c.chocolateId); },
          child: Text('🍫 Buy me a chocolate (${c.chocolateId})', style: const TextStyle(color: Colors.white))),
        const SizedBox(height: 20),
        ElevatedButton.icon(icon: const Icon(Icons.share),
          label: const Text('Share this game'),
          onPressed: () { widget.audio.click(); Share.share('Check out ${c.displayName}! ${c.tagline}'); }),
        TextButton(onPressed: () => InAppReview.instance.openStoreListing(),
          child: const Text('Rate us ⭐', style: TextStyle(color: Colors.white70))),
      ]),
    );
  }
  Widget _row(String free, String pro) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(free, style: const TextStyle(color: Colors.white54))),
      const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
      Expanded(child: Text(pro, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
    ]));
}
