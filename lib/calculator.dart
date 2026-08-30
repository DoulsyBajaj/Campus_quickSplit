import 'models.dart';

class SplitCalculator {
  static Map<String, double> calculateSplits({
    required double totalAmount,
    required List<String> participants,
    required SplitType splitType,
    required Map<String, double> inputValues,
  }) {
    Map<String, double> splits = {};

    if (participants.isEmpty) return splits;

    switch (splitType) {
      case SplitType.uniform:
        double rawShare = totalAmount / participants.length;
        double roundedShare = double.parse(rawShare.toStringAsFixed(2));
  
        for (var p in participants) {
          splits[p] = roundedShare;
        }
  
        double assignedTotal = roundedShare * participants.length;
        double remainder = double.parse((totalAmount - assignedTotal).toStringAsFixed(2));
        if (remainder != 0.0 && participants.isNotEmpty) {
          splits[participants.first] = double.parse((splits[participants.first]! + remainder).toStringAsFixed(2));
        }
        break;

      case SplitType.exact:
        for (var p in participants) {
          splits[p] = inputValues[p] ?? 0.0;
        }
        break;

      case SplitType.ratio:
        // Treats input values as percentages summing up to 100%
        double totalPct = inputValues.values.fold(0.0, (sum, val) => sum + val);
        if ((totalPct - 100.0).abs() > 0.01) {
          throw Exception("Percentage splits must equal exactly 100%. Current sum: ${totalPct.toStringAsFixed(1)}%");
        }
        for (var p in participants) {
          double pct = inputValues[p] ?? 0.0;
          splits[p] = double.parse((totalAmount * (pct / 100.0)).toStringAsFixed(2));
        }
        break;
    }

    return splits;
  }
}