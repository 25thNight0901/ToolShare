import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  DateTime? _availableFrom;
  DateTime? _availableTo;
  List<DateTime> _disabledDates = [];
  double _balance = 0.0;
  bool _canReserve = true; // track if reservation allowed
  String? _denyReason;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchUserBalance();
  }

  Future<void> _loadData() async {
    try {
      final productSnapshot = await widget.productRef.get();
      final productData = productSnapshot.data() as Map<String, dynamic>?;

      DateTime now = DateTime.now();
      DateTime availableFrom = now;
      DateTime availableTo = now.add(const Duration(days: 30));

      if (productData != null) {
        availableFrom =
            (productData['availableFrom'] as Timestamp?)?.toDate() ??
            availableFrom;
        availableTo =
            (productData['availableTo'] as Timestamp?)?.toDate() ?? availableTo;
      }

      final reservationsSnapshot =
          await FirebaseFirestore.instance
              .collection('reservations')
              .where('productId', isEqualTo: widget.productRef.id)
              .get();

      List<DateTime> disabledDates = [];

      for (var doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final reservedFrom = (data['reservedFrom'] as Timestamp).toDate();
        final reservedTo = (data['reservedTo'] as Timestamp).toDate();

        for (
          var d = reservedFrom;
          !d.isAfter(reservedTo);
          d = d.add(const Duration(days: 1))
        ) {
          disabledDates.add(d);
        }
      }

      DateTime startDate = DateTime(2000);
      DateTime endDate = DateTime(2100);

      for (
        var d = startDate;
        d.isBefore(availableFrom);
        d = d.add(const Duration(days: 1))
      ) {
        disabledDates.add(d);
      }
      for (
        var d = availableTo.add(const Duration(days: 1));
        d.isBefore(endDate);
        d = d.add(const Duration(days: 1))
      ) {
        disabledDates.add(d);
      }

      setState(() {
        _availableFrom = availableFrom;
        _availableTo = availableTo;
        _disabledDates = disabledDates;
        _selectedRange = DateTimeRange(
          start: availableFrom,
          end: availableFrom.add(const Duration(days: 1)),
        );
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _fetchUserBalance() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final QuerySnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('balances')
                .where('uid', isEqualTo: user.uid)
                .get();
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data() as Map<String, dynamic>;

          final dynamic balanceData = data['balance'];

          if (balanceData != null) {
            if (balanceData is num) {
              _balance = balanceData.toDouble();
            } else if (balanceData is String) {
              _balance = double.tryParse(balanceData) ?? 0.0;
            } else {
              _balance = 0.0;
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user balance: $e')),
        );
      }
    }
  }

  int get _totalDays => _selectedRange?.duration.inDays ?? 0;
  double get _totalPrice => _totalDays * widget.pricePerDay;

  Future<bool> _isOverlappingReservation() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('reservations')
              .where('productId', isEqualTo: widget.productRef.id)
              .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final reservedFrom = (data['reservedFrom'] as Timestamp).toDate();
        final reservedTo = (data['reservedTo'] as Timestamp).toDate();

        final existingRange = DateTimeRange(
          start: reservedFrom,
          end: reservedTo,
        );

        if (_selectedRange!.start.isBefore(existingRange.end) &&
            _selectedRange!.end.isAfter(existingRange.start)) {
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
    if (_selectedRange == null) return;

    setState(() {
      _canReserve = true;
      _denyReason = null;
    });

    if (_balance < _totalPrice) {
      setState(() {
        _canReserve = false;
        _denyReason = 'Insufficient balance';
      });
      return;
    }

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
      await FirebaseFirestore.instance.collection('reservations').add({
        'productId': widget.productRef.id,
        'reservedFrom': _selectedRange!.start,
        'reservedTo': _selectedRange!.end,
        'totalDays': _totalDays,
        'totalPrice': _totalPrice,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
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
    if (_availableFrom == null || _availableTo == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
                _canReserve = true;
                _denyReason = null;
              });
            },
            availableFrom: _availableFrom!,
            availableTo: _availableTo!,
            disabledDates: _disabledDates,
          ),
          const SizedBox(height: 20),
          Text(
            'Total: ${_totalPrice.toStringAsFixed(2)} € ($_totalDays day${_totalDays != 1 ? 's' : ''})',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_balance != null)
            Text(
              'Your balance: ${_balance!.toStringAsFixed(2)} €',
              style: TextStyle(
                fontSize: 14,
                color: _balance! < _totalPrice ? Colors.red : Colors.green,
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _canReserve ? null : Colors.red,
            ),
            onPressed:
                (_selectedRange != null && _canReserve)
                    ? _confirmReservation
                    : null,
            icon:
                _canReserve ? const Icon(Icons.check) : const Icon(Icons.close),
            label: Text(
              _canReserve ? 'Confirm Reservation' : 'Reservation Denied',
            ),
          ),
          if (!_canReserve && _denyReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _denyReason!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
