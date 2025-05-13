import 'package:flutter/material.dart';

class ReservationBottomSheet extends StatefulWidget {
  const ReservationBottomSheet({super.key});

  @override
  State<ReservationBottomSheet> createState() => _ReservationBottomSheetState();
}

class _ReservationBottomSheetState extends State<ReservationBottomSheet> {
  DateTimeRange? _selectedRange;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Reservation Period',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _pickDateRange,
            child: const Text('Choose Date Range'),
          ),
          if (_selectedRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Selected: ${_selectedRange!.start.toLocal().toString().split(' ')[0]} → ${_selectedRange!.end.toLocal().toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
                _selectedRange != null
                    ? () {
                      // TODO: Save reservation logic
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reserved!')),
                      );
                    }
                    : null,
            child: const Text('Confirm Reservation'),
          ),
        ],
      ),
    );
  }
}
