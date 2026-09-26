extension Fmt on double {
  String fmt([int decimals = 1]) => toStringAsFixed(decimals);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String formatDayTime(DateTime d) =>
    '${d.day} ${_months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
