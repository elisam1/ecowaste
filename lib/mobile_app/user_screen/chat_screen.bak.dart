import 'package:flutter/material.dart';
import 'package:flutter_application_1/mobile_app/constants/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: AppColors.navy,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pickup Chat', icon: Icon(Icons.local_shipping_rounded)),
            Tab(text: 'Market Chat', icon: Icon(Icons.shopping_bag_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_PickupChatTab(), _MarketChatTab()],
      ),
    );
  }
}

class _PickupChatTab extends StatelessWidget {
  const _PickupChatTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _TeamChatCard(),
        // Add more pickup-related chat cards here
      ],
    );
  }
}

class _MarketChatTab extends StatelessWidget {
  const _MarketChatTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.warning,
              child: const Icon(Icons.shopping_bag, color: Colors.white),
            ),
            title: const Text('EcoMarket Support'),
            subtitle: const Text('Chat about EcoMarket orders and products'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Implement market chat detail
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Market chat coming soon!')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TeamChatCard extends StatelessWidget {
  const _TeamChatCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success,
          child: const Icon(Icons.support_agent, color: Colors.white),
        ),
        title: const Text('App Team'),
        subtitle: const Text('Send a message to the EcoWaste team'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _TeamChatDetail()),
          );
        },
      ),
    );
  }
}

class _TeamChatDetail extends StatelessWidget {
  const _TeamChatDetail();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Team'),
        backgroundColor: AppColors.navy,
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'This is your direct line to the EcoWaste app team.\nAsk questions, report issues, or get updates here!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: const Color(0xFF1A5D4A),
                  onPressed: () {},
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
