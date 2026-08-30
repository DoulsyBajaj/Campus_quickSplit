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

class MinCashFlowCalculator {
  // Minimizes transactions using a greedy approach on net balances
  static List<Settlement> simplifyDebts(Map<String, double> netBalances) {
    List<Settlement> settlements = [];
    Map<String, double> balances = Map.from(netBalances);

    while (true) {
      String maxDebtor = '';
      String maxCreditor = '';
      double maxDeficit = 0.0;
      double maxCredit = 0.0;

      balances.forEach((person, balance) {
        if (balance < -0.01 && balance < maxDeficit) {
          maxDeficit = balance;
          maxDebtor = person;
        }
        if (balance > 0.01 && balance > maxCredit) {
          maxCredit = balance;
          maxCreditor = person;
        }
      });

      // Stop when all net balances are settled (close to 0)
      if (maxDebtor.isEmpty || maxCreditor.isEmpty) break;

      double amountToSettle = maxCredit < (-maxDeficit) ? maxCredit : (-maxDeficit);
      amountToSettle = double.parse(amountToSettle.toStringAsFixed(2));

      balances[maxDebtor] = balances[maxDebtor]! + amountToSettle;
      balances[maxCreditor] = balances[maxCreditor]! - amountToSettle;

      settlements.add(Settlement(
        sender: maxDebtor,
        receiver: maxCreditor,
        amount: amountToSettle,
      ));
    }

    return settlements;
  }
}