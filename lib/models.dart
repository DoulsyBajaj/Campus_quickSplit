enum SplitType { uniform, exact, ratio }

class Expense {
  final String id;
  final String title;
  final double totalAmount;
  final Map<String, double> paidByMap; // Tracks multi-payer upfront contributions
  final SplitType splitType;
  final Map<String, double> participantValues;

  Expense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.paidByMap,
    required this.splitType,
    required this.participantValues,
  });

  String get primaryPaidBySummary {
    final paidEntries = paidByMap.entries.where((e) => e.value > 0).toList();
    if (paidEntries.isEmpty) return 'Nobody';
    if (paidEntries.length == 1) return paidEntries.first.key;
    return '${paidEntries.first.key} +${paidEntries.length - 1} others';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'totalAmount': totalAmount,
        'paidByMap': paidByMap,
        'splitType': splitType.index,
        'participantValues': participantValues,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'],
        title: map['title'],
        totalAmount: (map['totalAmount'] as num).toDouble(),
        paidByMap: Map<String, double>.from(
          (map['paidByMap'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        ),
        splitType: SplitType.values[map['splitType']],
        participantValues: Map<String, double>.from(
          (map['participantValues'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        ),
      );
}

class Settlement {
  final String sender;
  final String receiver;
  final double amount;

  Settlement({
    required this.sender,
    required this.receiver,
    required this.amount,
  });
}