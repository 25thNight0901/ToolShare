import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class InlineDateRangePicker extends StatelessWidget {
  final void Function(DateTimeRange) onChanged;
  final DateTime availableFrom;
  final DateTime availableTo;
  final List<DateTime> disabledDates;

  const InlineDateRangePicker({
    super.key,
    required this.onChanged,
    required this.availableFrom,
    required this.availableTo,
    required this.disabledDates,
  });

  @override
  Widget build(BuildContext context) {
    return SfDateRangePicker(
      view: DateRangePickerView.month,
      selectionMode: DateRangePickerSelectionMode.range,
      showActionButtons: false,
      minDate: availableFrom,
      maxDate: availableTo,
      initialSelectedRange: PickerDateRange(
        availableFrom,
        availableFrom.add(const Duration(days: 3)),
      ),
      monthViewSettings: DateRangePickerMonthViewSettings(
        blackoutDates: disabledDates,
        viewHeaderStyle: const DateRangePickerViewHeaderStyle(
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      monthCellStyle: DateRangePickerMonthCellStyle(
        blackoutDateTextStyle: const TextStyle(
          color: Colors.red,
          decoration: TextDecoration.lineThrough,
        ),
        blackoutDatesDecoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      ),
      onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
        if (args.value is PickerDateRange) {
          final range = args.value as PickerDateRange;
          if (range.startDate != null && range.endDate != null) {
            onChanged(
              DateTimeRange(start: range.startDate!, end: range.endDate!),
            );
          }
        }
      },
    );
  }
}
