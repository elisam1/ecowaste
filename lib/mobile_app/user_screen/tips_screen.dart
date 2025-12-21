import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/constants/app_colors.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tips & Info'),
        backgroundColor: AppColors.navy,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PromoCard(),
          SizedBox(height: 20),
          _RecyclingTipsCard(),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.indigo, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Ghana Digital Centres',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Empowering Communities',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          SizedBox(height: 16),
          Text(
            '🎓 Free Digital Skills Training\n'
            '💻 Access to Computers & Internet\n'
            '📱 Technology Education Programs\n'
            '🌍 Building Digital Ghana Together',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _RecyclingTipsCard extends StatelessWidget {
  const _RecyclingTipsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Recycling Tips',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 10),
            Text('♻️ Rinse containers before recycling'),
            Text('♻️ Remove caps and lids'),
            Text('♻️ Flatten cardboard boxes'),
            Text('♻️ Keep plastics separate'),
            Text('♻️ No plastic bags in bins'),
            SizedBox(height: 10),
            Text(
              'Proper sorting helps maximize recycling! ',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
