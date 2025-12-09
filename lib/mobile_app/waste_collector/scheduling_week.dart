import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class WeeklySchedulingPage extends StatefulWidget {
  final String collectorId;

  /// Optional: provide a starting set of towns to show in the dropdown
  /// (collectors can still add new ones on the fly).
  final List<String> suggestedTowns;

  const WeeklySchedulingPage({
    super.key,
    required this.collectorId,
    this.suggestedTowns = const [
      'Accra',
      'Tema',
      'Kumasi',
      'Cape Coast',
      'Takoradi',
      'Tamale',
      'Koforidua',
      'Ho',
      'Sunyani',
      'Bolgatanga',
      'Wa',
      'Kasoa',
      'Madina',
      'Ashaiman',
    ],
  });

  @override
  State<WeeklySchedulingPage> createState() => _WeeklySchedulingPageState();
}

class _WeeklySchedulingPageState extends State<WeeklySchedulingPage>
    with TickerProviderStateMixin {
  /// Anchor date determines which week we're showing.
  /// The UI will show the Sunday→Saturday that contains this anchor.
  DateTime _anchorDate = _todayDateOnly();

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  static DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Compute the Sunday that starts the week of [date].
  DateTime _sundayOf(DateTime date) {
    // In Dart, weekday: Mon=1 ... Sun=7
    final daysFromSunday = date.weekday % 7; // Sun -> 0, Mon -> 1, ...
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysFromSunday));
  }

  /// Sunday → Saturday dates for the week containing [_anchorDate]
  List<DateTime> get _weekDates {
    final start = _sundayOf(_anchorDate);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _dayLabel(DateTime d) => DateFormat('EEE').format(d); // Sun, Mon...
  String _humanDate(DateTime d) => DateFormat('d MMM').format(d); // 17 Aug
  String _weekSpanLabel() {
    final dates = _weekDates;
    final a = dates.first;
    final b = dates.last;
    final sameMonth = a.month == b.month && a.year == b.year;
    if (sameMonth) {
      return '${DateFormat('d').format(a)}–${DateFormat('d MMM, yyyy').format(b)}';
    } else {
      return '${DateFormat('d MMM').format(a)} – ${DateFormat('d MMM, yyyy').format(b)}';
    }
  }

  void _toPrevWeek() {
    setState(() {
      _anchorDate = _anchorDate.subtract(const Duration(days: 7));
      _slideController.reset();
      _slideController.forward();
    });
  }

  void _toNextWeek() {
    setState(() {
      _anchorDate = _anchorDate.add(const Duration(days: 7));
      _slideController.reset();
      _slideController.forward();
    });
  }

  void _toThisWeek() {
    setState(() {
      _anchorDate = _todayDateOnly();
      _slideController.reset();
      _slideController.forward();
    });
  }

  /// Firestore helpers
  DocumentReference<Map<String, dynamic>> get _collectorDoc => FirebaseFirestore
      .instance
      .collection('collectors')
      .doc(widget.collectorId);

  /// Update towns for a specific date (merge preserving other dates).
  Future<void> _updateTownsForDate(DateTime date, List<String> towns) async {
    final key = _dateKey(date);

    try {
      // First, get the current document to preserve existing schedule data
      final currentDoc = await _collectorDoc.get();
      final currentData = currentDoc.data();
      Map<String, dynamic> currentSchedule = {};

      if (currentData != null && currentData['schedule'] != null) {
        currentSchedule = Map<String, dynamic>.from(currentData['schedule']);
      }

      // Update only the specific date while preserving other dates
      currentSchedule[key] = towns;

      // Save the updated schedule
      await _collectorDoc.set({
        'schedule': currentSchedule,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating schedule: $e');
      // Fallback to the original method if there's an error
      await _collectorDoc.set({
        'schedule': {key: towns},
      }, SetOptions(merge: true));
    }
  }

  /// Remove a town from a specific date.
  Future<void> _removeTownFromDate(
    DateTime date,
    String town,
    List<String> current,
  ) async {
    final updated = List<String>.from(current)..remove(town);
    await _updateTownsForDate(date, updated);
  }

  /// Add a single custom town to the date (deduped).
  Future<void> _addCustomTown(
    DateTime date,
    String town,
    List<String> current,
  ) async {
    if (town.trim().isEmpty) return;

    // Create a new list with the new town added, ensuring no duplicates
    final updated = List<String>.from(current);
    final trimmedTown = town.trim();

    // Only add if it's not already in the list
    if (!updated.contains(trimmedTown)) {
      updated.add(trimmedTown);
      await _updateTownsForDate(date, updated);
    }
  }

  /// Stream of the collector's schedule map to reflect live changes.
  Stream<Map<String, dynamic>> get _scheduleStream {
    return _collectorDoc.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return <String, dynamic>{};
      final schedule =
          (data['schedule'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v)),
          ) ??
          {};
      return schedule;
    });
  }

  /// Save the entire weekly schedule to Firestore
  Future<void> _saveWeeklySchedule(Map<String, dynamic> currentSchedule) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get the current schedule data
      final scheduleMap = currentSchedule.map(
        (k, v) => MapEntry(k, List<String>.from(v ?? const [])),
      );

      // Filter out empty dates (dates with no towns) and convert towns to lowercase
      final nonEmptySchedule = <String, dynamic>{};
      scheduleMap.forEach((dateKey, towns) {
        if (towns.isNotEmpty) {
          nonEmptySchedule[dateKey] = towns
              .map((town) => town.toLowerCase())
              .toList();
        }
      });

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('weekly_schedules')
          .doc(widget.collectorId)
          .set({
            'schedule': nonEmptySchedule,
            'lastScheduleUpdate': FieldValue.serverTimestamp(),
            'collectorId': widget.collectorId,
          }, SetOptions(merge: true));

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Weekly schedule saved successfully! Schedule has been reset.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Reset the schedule by clearing all towns for all dates
      final weekDates = _weekDates;
      for (final date in weekDates) {
        await _updateTownsForDate(date, []);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save schedule: ${e.toString()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// A stylish dialog to add a custom town.
  Future<void> _showAddTownDialog({
    required DateTime date,
    required List<String> current,
  }) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_city,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Custom Town',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                          ),
                          Text(
                            _humanDate(date),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter town name',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: Colors.blue.shade300,
                        width: 2,
                      ),
                    ),
                    prefixIcon: Icon(Icons.place, color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.of(ctx).pop(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final val = controller.text.trim();
                          if (val.isNotEmpty) {
                            await _addCustomTown(date, val, current);
                          }
                          if (context.mounted) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Add Town',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build one row (day card) with multi-select + custom add.
  Widget _buildDayCard({
    required DateTime date,
    required List<String> townsForDate,
  }) {
    // Merge suggested towns with already-selected towns so they always appear.
    final uniqueSet = {...widget.suggestedTowns, ...townsForDate};
    final allItems = uniqueSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final isToday = date == _todayDateOnly();

    // Determine if it's weekend
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    // Determine if it's a past date
    final isPastDate = date.isBefore(_todayDateOnly());

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Card(
        elevation: isToday ? 6 : 2,
        shadowColor: isToday ? Colors.blue.withOpacity(0.3) : Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isToday ? Colors.blue.shade300 : Colors.grey.shade200,
            width: isToday ? 2 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isToday
                  ? [Colors.blue.shade50, Colors.white]
                  : isWeekend
                  ? [Colors.amber.shade50, Colors.white]
                  : [Colors.grey.shade50, Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Day + Date + count badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isToday
                            ? [Colors.blue.shade600, Colors.blue.shade700]
                            : isWeekend
                            ? [Colors.amber.shade400, Colors.amber.shade500]
                            : [Colors.grey.shade400, Colors.grey.shade500],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isToday
                                      ? Colors.blue
                                      : isWeekend
                                      ? Colors.amber
                                      : Colors.grey)
                                  .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isWeekend ? Icons.weekend : Icons.work_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dayLabel(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _humanDate(date),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),

              const SizedBox(height: 20),

              // Selected towns chips
              if (townsForDate.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: townsForDate.map((town) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPastDate
                            ? Colors.grey.shade200
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPastDate
                              ? Colors.grey.shade400
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: isPastDate
                                ? Colors.grey.shade600
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            town,
                            style: TextStyle(
                              color: isPastDate
                                  ? Colors.grey.shade600
                                  : Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (!isPastDate) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () =>
                                  _removeTownFromDate(date, town, townsForDate),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Multi-select button
              if (isPastDate) ...[
                // Past date - show disabled state
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_clock,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This date has passed - scheduling is disabled',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Current/future date - show normal controls
                Container(
                  width: double.infinity,
                  child: MultiSelectDialogField<String>(
                    items: allItems
                        .map((t) => MultiSelectItem<String>(t, t))
                        .toList(),
                    initialValue: townsForDate,
                    title: const Text('Select Towns'),
                    searchable: true,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    buttonIcon: Icon(
                      Icons.add_location_alt_outlined,
                      color: Colors.blue.shade600,
                    ),
                    buttonText: Text(
                      townsForDate.isEmpty
                          ? 'Select towns for this date'
                          : 'Modify selected towns',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    chipDisplay: MultiSelectChipDisplay.none(),
                    onConfirm: (values) async {
                      await _updateTownsForDate(date, values);
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Action buttons
              if (!isPastDate) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddTownDialog(
                          date: date,
                          current: townsForDate,
                        ),
                        icon: const Icon(Icons.add_location, size: 18),
                        label: const Text(
                          'Add Custom',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.blue.shade300),
                          foregroundColor: Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (townsForDate.isNotEmpty)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            // Clear all towns for this date
                            await _updateTownsForDate(date, []);
                          },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text(
                            'Clear',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.red.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _weekDates;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        title: Text(
          'Weekly Schedule',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          // Week header + controls
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous week',
                      onPressed: _toPrevWeek,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.chevron_left,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _weekSpanLabel(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'Sunday – Saturday',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next week',
                      onPressed: _toNextWeek,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toThisWeek,
                      icon: const Icon(Icons.today, size: 18),
                      label: const Text(
                        'Go to This Week',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Streams: schedule only
          Expanded(
            child: StreamBuilder<Map<String, dynamic>>(
              stream: _scheduleStream,
              builder: (context, scheduleSnap) {
                final scheduleMap = (scheduleSnap.data ?? <String, dynamic>{})
                    .map(
                      (k, v) => MapEntry(k, List<String>.from(v ?? const [])),
                    );

                return Column(
                  children: [
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: weekDates.length,
                          itemBuilder: (context, index) {
                            final date = weekDates[index];
                            final key = _dateKey(date);
                            final townsForDate = List<String>.from(
                              scheduleMap[key] ?? const <String>[],
                            );

                            return AnimatedContainer(
                              duration: Duration(
                                milliseconds: 100 + (index * 50),
                              ),
                              curve: Curves.easeOutCubic,
                              child: _buildDayCard(
                                date: date,
                                townsForDate: townsForDate,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Save Button
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _saveWeeklySchedule(scheduleSnap.data ?? {}),
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text(
                          'Save Weekly Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
