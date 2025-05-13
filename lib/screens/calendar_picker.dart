import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class InlineDateRangePicker extends StatelessWidget {
  final void Function(DateTimeRange) onChanged;

  const InlineDateRangePicker({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SfDateRangePicker(
      view: DateRangePickerView.month,
      selectionMode: DateRangePickerSelectionMode.range,
      showActionButtons: false,
      initialSelectedRange: PickerDateRange(
        DateTime.now(),
        DateTime.now().add(const Duration(days: 3)),
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
