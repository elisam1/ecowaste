import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

///import 'package:flutter_application_1/mobile_app/chat_page/chat_page.dart';
// ignore: unused_import
import 'package:flutter_application_1/mobile_app/chat_page/chatlist_page.dart';
import 'package:flutter_application_1/mobile_app/routes/app_route.dart';
import 'package:intl/intl.dart';

class PickupManagementPage extends StatefulWidget {
  final String collectorId;
  final String collectorName;
  final String collectorTown;
  //final int initialTabIndex;

  const PickupManagementPage({
    super.key,
    required this.collectorId,
    required this.collectorName,
    required this.collectorTown,
    //this.initialTabIndex=0,
  });

  @override
  State<PickupManagementPage> createState() => _PickupManagementPageState();
}

class _PickupManagementPageState extends State<PickupManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      //initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTodaySchedule() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTodayScheduleModal(),
    );
  }

  Widget _buildTodayScheduleModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Schedule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Schedule content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pickup_requests')
                  .where('collectorId', isEqualTo: widget.collectorId)
                  .where(
                    'pickupDate',
                    isGreaterThanOrEqualTo: DateTime.now().copyWith(
                      hour: 0,
                      minute: 0,
                      second: 0,
                      millisecond: 0,
                      microsecond: 0,
                    ),
                  )
                  .where(
                    'pickupDate',
                    isLessThanOrEqualTo: DateTime.now().copyWith(
                      hour: 23,
                      minute: 59,
                      second: 59,
                      millisecond: 999,
                      microsecond: 999,
                    ),
                  )
                  .orderBy('pickupDate')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todayRequests = snapshot.data?.docs ?? [];

                if (todayRequests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No pickups scheduled for today',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enjoy your day off!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: todayRequests.length,
                  itemBuilder: (context, index) {
                    final request =
                        todayRequests[index].data() as Map<String, dynamic>;
                    final pickupTime = request['pickupDate']?.toDate();
                    final formattedTime = pickupTime != null
                        ? DateFormat('h:mm a').format(pickupTime)
                        : 'Unknown time';

                    final status = request['status'] ?? 'pending';
                    final statusColor = _getStatusColor(status);
                    final statusText = _getStatusText(status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Time indicator
                          Container(
                            width: 4,
                            height: 60,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Request details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  request['userName'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  request['userTown'] ?? 'Unknown Location',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (request['wasteCategories'] != null) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    children:
                                        (request['wasteCategories']
                                                as List<dynamic>)
                                            .take(3)
                                            .map(
                                              (category) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  category.toString(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Pickup Management',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Calendar Icon
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.blue),
            onPressed: () {
              _showTodaySchedule();
            },
            tooltip: 'Today\'s Schedule',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.inbox), text: 'Incoming Requests'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Your Pickups'),
            //Tab(icon: Icon(Icons.chat), text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIncomingRequestsTab(),
          _buildYourPickupsTab(),

          //const ChatListPage(),
        ],
      ),
      // Floating Action Button for Quick Scan
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF42A5F5)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF26A69A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.chatlistpage),
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat, color: Colors.white),
              SizedBox(width: 3),
              Text(
                'Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('status', isEqualTo: 'pending')
          .where(
            'collectorId',
            whereIn: ['', widget.collectorId],
          ) // Unassigned requests (empty string)
          .where(
            'userTown',
            isEqualTo: _getCollectorTown(),
          ) // Only show requests in collector's town
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No incoming requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'New pickup requests will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // The stream will automatically refresh
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final request = doc.data() as Map<String, dynamic>;
              return _buildIncomingRequestCard(doc.id, request);
            },
          ),
        );
      },
    );
  }

  Widget _buildYourPickupsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('collectorId', isEqualTo: widget.collectorId)
          .orderBy(
            'pickupDate',
            descending: false,
          ) // Order by pickup date ascending
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No accepted pickups yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Accepted pickup requests will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Group requests by date
        final requests = snapshot.data!.docs;
        final groupedRequests = _groupRequestsByDate(requests);

        return RefreshIndicator(
          onRefresh: () async {
            // The stream will automatically refresh
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedRequests.length,
            itemBuilder: (context, index) {
              final dateGroup = groupedRequests[index];
              return _buildDateGroupCard(dateGroup);
            },
          ),
        );
      },
    );
  }

  Widget _buildIncomingRequestCard(
    String requestId,
    Map<String, dynamic> request,
  ) {
    final wasteCategories = request['wasteCategories'] as List<dynamic>? ?? [];
    final pickupDate = request['pickupDate'];
    final createdAt = request['createdAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#${requestId.substring(0, 6)}',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'GH₵ ${request['totalAmount']?.toString() ?? _calculateEarning(wasteCategories)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Info
          Row(
            children: [
              Icon(Icons.person, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Text(
                request['userName'] ?? 'Unknown User',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Location
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request['userTown'] ?? 'Location not specified',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Phone
          Row(
            children: [
              Icon(Icons.phone, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Text(
                request['userPhone'] ?? 'No phone',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(pickupDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items
          Text(
            'Items: ${wasteCategories.join(', ')}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 4),

          // Payment Details
          if (request['binCount'] != null && request['pricePerBin'] != null)
            Row(
              children: [
                Icon(Icons.payment, color: Colors.grey[500], size: 16),
                const SizedBox(width: 4),
                Text(
                  '${request['binCount']} bins × GH₵${request['pricePerBin']} = GH₵${request['totalAmount']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          const SizedBox(height: 4),

          Text(
            'Requested ${_getTimeAgo(createdAt)}',
            style: TextStyle(color: Colors.green[500], fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showDeclineDialog(requestId);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'collectorId': widget.collectorId,
                        'requestId': requestId,
                        'collectorName':
                            request['collectorName'] ?? 'Collector',
                        'userName': request['userName'] ?? 'User',
                      },
                    );
                  },
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _showAcceptDialog(requestId);
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYourPickupCard(String requestId, Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final wasteCategories = request['wasteCategories'] as List<dynamic>? ?? [];
    final pickupDate = request['pickupDate'];
    final updatedAt = request['updatedAt'];

    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#${requestId.substring(0, 6)}',
                  style: const TextStyle(
                    //color: statusColor[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    // color: statusColor[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'GH₵ ${request['totalAmount']?.toString() ?? _calculateEarning(wasteCategories)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Info
          Row(
            children: [
              Icon(Icons.person, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Text(
                request['userName'] ?? 'Unknown User',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Location and Phone
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request['userTown'] ?? 'Location not specified',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.phone, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Text(
                request['userPhone'] ?? 'No phone',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, color: Colors.grey[500], size: 16),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(pickupDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items
          Text(
            'Items: ${wasteCategories.join(', ')}',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 4),

          // Payment Details
          if (request['binCount'] != null && request['pricePerBin'] != null)
            Row(
              children: [
                Icon(Icons.payment, color: Colors.grey[500], size: 16),
                const SizedBox(width: 4),
                Text(
                  '${request['binCount']} bins × GH₵${request['pricePerBin']} = GH₵${request['totalAmount']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          const SizedBox(height: 4),

          Text(
            'Updated ${_getTimeAgo(updatedAt)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          _buildActionButtons(requestId, status, request),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    String requestId,
    String status,
    Map<String, dynamic> request,
  ) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateRequestStatus(requestId, 'in_progress'),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Pickup'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'collectorId': widget.collectorId,
                      'requestId': requestId,
                      'collectorName': request['collectorName'] ?? 'Collector',
                      'userName': request['userName'] ?? 'User',
                    },
                  );
                },
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'in_progress':
        return Row(
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: ElevatedButton.icon(
                onPressed: () => _showCompleteDialog(requestId),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Flexible(
            //   fit: FlexFit.tight,
            //   child: ElevatedButton.icon(
            //     onPressed: () => _navigateToLocation(requestId),
            //     // _navigateToLocation(requestId, data),
            //     //_showRequestDetails(doc.id, data),
            //     icon: const Icon(Icons.navigation, size: 18),
            //     label: const Text('Navigate'),
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: Colors.blue,
            //       padding: const EdgeInsets.symmetric(
            //         horizontal: 4,
            //         vertical: 12,
            //       ),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //     ),
            //   ),
            // ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'collectorId': widget.collectorId,
                      'requestId': requestId,
                      'collectorName': request['collectorName'] ?? 'Collector',
                      'userName': request['userName'] ?? 'User',
                    },
                  );
                },
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'completed':
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      ' COMPLETED',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteDialog(requestId),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );

      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Status: ${status.toUpperCase()}',
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }

  // Helper Methods
  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Not set';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Invalid date';
    }

    return DateFormat('MMM dd, hh:mm a').format(dateTime);
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'some time ago';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'some time ago';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  String _calculateEarning(List<dynamic> wasteCategories) {
    // Simple earning calculation based on waste categories
    int baseEarning = 0;
    for (var category in wasteCategories) {
      switch (category.toString().toLowerCase()) {
        case 'electronics':
          baseEarning += 60;
          break;
        case 'metal':
          baseEarning += 40;
          break;
        case 'plastic':
          baseEarning += 25;
          break;
        case 'paper':
          baseEarning += 20;
          break;
        case 'glass':
          baseEarning += 15;
          break;
        default:
          baseEarning += 10;
      }
    }
    return baseEarning.toString();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_confirmation':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending_confirmation':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  // Firebase Operations
  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      final updateData = {
        'status': newStatus,
        if (newStatus == 'completed') ...{
          'updatedAt': FieldValue.serverTimestamp(),
          'collectorId': widget.collectorId,
        },
      };

      await FirebaseFirestore.instance
          .collection('pickup_requests')
          .doc(requestId)
          .update(updateData);

      // Create notification for the user about status change
      try {
        final requestDoc = await FirebaseFirestore.instance
            .collection('pickup_requests')
            .doc(requestId)
            .get();

        if (requestDoc.exists) {
          final requestData = requestDoc.data()!;
          final userId = requestData['userId'];

          if (userId != null) {
            String title = '';
            String message = '';

            switch (newStatus) {
              case 'accepted':
                title = '✅ Pickup Request Accepted';
                message =
                    'Your pickup request has been accepted by ${widget.collectorName}';
                break;
              case 'in_progress':
                title = '🚚 Pickup In Progress';
                message =
                    '${widget.collectorName} is on the way to collect your waste';
                break;
              case 'pending_confirmation':
                title = '🔍 Confirm Pickup Completion';
                message =
                    '${widget.collectorName} has marked your pickup as completed. Please confirm to release payment.';
                break;
              case 'completed':
                title = '🎉 Pickup Completed & Confirmed';
                message =
                    'Your waste pickup has been confirmed and payment has been released to ${widget.collectorName}';
                break;
              case 'cancelled':
                title = '❌ Pickup Request Cancelled';
                message =
                    'Your pickup request has been cancelled by ${widget.collectorName}';
                break;
            }

            if (title.isNotEmpty) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': userId,
                'type': 'pickup_status_update',
                'title': title,
                'message': message,
                'data': {
                  'pickupRequestId': requestId,
                  'collectorId': widget.collectorId,
                  'collectorName': widget.collectorName,
                  'status': newStatus,
                  'userTown': requestData['userTown'],
                  'pickupDate': requestData['pickupDate'],
                  'totalAmount': requestData['totalAmount'],
                  'binCount': requestData['binCount'],
                },
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      } catch (e) {
        print('Error creating pickup status notification: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request ${newStatus.replaceAll('_', ' ')} successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('pickup_requests')
          .doc(requestId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completed request deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Dialog Methods
  void _showAcceptDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Pickup Request'),
        content: const Text(
          'Are you sure you want to accept this pickup request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateRequestStatus(requestId, 'accepted');
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showDeclineDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Pickup Request'),
        content: const Text(
          'Are you sure you want to decline this pickup request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateRequestStatus(requestId, 'cancelled');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Pickup'),
        content: const Text(
          'Mark this pickup as completed?\n\n⚠️ User will be notified to confirm completion before payment is released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateRequestStatus(requestId, 'pending_confirmation');
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Completed Request'),
        content: const Text(
          'Are you sure you want to delete this completed pickup request?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRequest(requestId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // void _navigateToLocation(String requestId) {
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(const SnackBar(content: Text('Opening navigation...')));
  //   // Here you would integrate with maps/navigation
  //   // For example: launch Google Maps or Apple Maps
  // }

  // Get collector's town from widget parameter
  String _getCollectorTown() {
    return widget.collectorTown;
  }

  // Group requests by pickup date
  List<MapEntry<DateTime, List<QueryDocumentSnapshot>>> _groupRequestsByDate(
    List<QueryDocumentSnapshot> requests,
  ) {
    final Map<DateTime, List<QueryDocumentSnapshot>> grouped = {};

    for (final doc in requests) {
      final request = doc.data() as Map<String, dynamic>;
      final pickupDate = request['pickupDate'];

      if (pickupDate != null) {
        DateTime date;
        if (pickupDate is Timestamp) {
          date = pickupDate.toDate();
        } else if (pickupDate is DateTime) {
          date = pickupDate;
        } else {
          continue; // Skip invalid dates
        }

        // Create a date key with only year, month, and day (no time)
        final dateKey = DateTime(date.year, date.month, date.day);

        if (grouped.containsKey(dateKey)) {
          grouped[dateKey]!.add(doc);
        } else {
          grouped[dateKey] = [doc];
        }
      }
    }

    // Sort by date and convert to list
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries;
  }

  // Build a date group card that contains all requests for a specific date
  Widget _buildDateGroupCard(
    MapEntry<DateTime, List<QueryDocumentSnapshot>> dateGroup,
  ) {
    final date = dateGroup.key;
    final requests = dateGroup.value;
    final isToday = _isToday(date);
    final isTomorrow = _isTomorrow(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.blue.shade50
                  : isTomorrow
                  ? Colors.orange.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday
                    ? Colors.blue.shade200
                    : isTomorrow
                    ? Colors.orange.shade200
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isToday
                      ? Icons.today
                      : isTomorrow
                      ? Icons.event
                      : Icons.calendar_today,
                  color: isToday
                      ? Colors.blue.shade600
                      : isTomorrow
                      ? Colors.orange.shade600
                      : Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDateLabel(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Colors.blue.shade700
                              : isTomorrow
                              ? Colors.orange.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '${requests.length} pickup${requests.length > 1 ? 's' : ''} scheduled',
                        style: TextStyle(
                          fontSize: 14,
                          color: isToday
                              ? Colors.blue.shade600
                              : isTomorrow
                              ? Colors.orange.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.blue.shade100
                        : isTomorrow
                        ? Colors.orange.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isToday
                          ? Colors.blue.shade700
                          : isTomorrow
                          ? Colors.orange.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Requests for this date
          ...requests.map((doc) {
            final request = doc.data() as Map<String, dynamic>;
            return _buildYourPickupCard(doc.id, request);
          }).toList(),
        ],
      ),
    );
  }

  // Check if a date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Check if a date is tomorrow
  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  // Get a user-friendly date label
  String _getDateLabel(DateTime date) {
    if (_isToday(date)) {
      return 'Today';
    } else if (_isTomorrow(date)) {
      return 'Tomorrow';
    } else {
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    }
  }
}
