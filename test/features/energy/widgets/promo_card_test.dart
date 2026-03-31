import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meter_texas/features/energy/presentation/widgets/promo_card.dart';

void main() {
  testWidgets('renders badge title description sponsor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PromoCard(
          badgeText: 'Sponsored',
          title: 'Promo Title',
          description: 'Promo Description',
          sponsorName: 'Sponsor',
          imageLayer: Container(color: Colors.black),
          button: ElevatedButton(onPressed: () {}, child: const Text('CTA')),
        ),
      ),
    );

    expect(find.text('Promo Title'), findsOneWidget);
    expect(find.text('Promo Description'), findsOneWidget);
    expect(find.text('SPONSOR'), findsOneWidget);
  });
}
