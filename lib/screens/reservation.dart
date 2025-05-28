import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toolshare/screens/calendar_picker.dart';

class ReservationBottomSheet extends StatefulWidget {
  final DocumentReference productRef;
  final String title;
  final double pricePerDay;

  const ReservationBottomSheet({
    super.key,
    required this.productRef,
    required this.title,
    required this.pricePerDay,
  });

  @override
  State<ReservationBottomSheet> createState() => _ReservationBottomSheetState();
}

class _ReservationBottomSheetState extends State<ReservationBottomSheet> {
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: now,
      end: now.add(const Duration(days: 1)),
    );
  }

  int get _totalDays {
    if (_selectedRange == null) return 0;
    return _selectedRange!.duration.inDays;
  }

  double get _totalPrice => _totalDays * widget.pricePerDay;

  Future<bool> _isOverlappingReservation() async {
    try {
      final productSnapshot = await widget.productRef.get();
      final data = productSnapshot.data() as Map<String, dynamic>?;

      if (data == null) return false;

      final reservedFrom = (data['reservedFrom'] as Timestamp?)?.toDate();
      final reservedTo = (data['reservedTo'] as Timestamp?)?.toDate();

      if (reservedFrom != null && reservedTo != null) {
        final reservedRange = DateTimeRange(
          start: reservedFrom,
          end: reservedTo,
        );

        if (_selectedRange!.start.isBefore(reservedRange.end) &&
            _selectedRange!.end.isAfter(reservedRange.start)) {
          return true;
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking reservations: $e')),
        );
      }
    }
    return false;
  }

  Future<void> _confirmReservation() async {
    final isOverlapping = await _isOverlappingReservation();

    if (isOverlapping) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selected dates overlap with an existing reservation',
            ),
          ),
        );
      }
      return;
    }

    try {
      await widget.productRef.update({
        'reservedFrom': _selectedRange!.start,
        'reservedTo': _selectedRange!.end,
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reservation successful')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          InlineDateRangePicker(
            onChanged: (range) {
              setState(() {
                _selectedRange = range;
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Total: ${_totalPrice.toStringAsFixed(2)} € ($_totalDays day${_totalDays > 1 ? 's' : ''})',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedRange != null ? _confirmReservation : null,
            child: const Text('Confirm Reservation'),
          ),
        ],
      ),
    );
  }
}
