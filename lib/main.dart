import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart' hide Settlement;
import 'calculator.dart';
import 'min_cash_flow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('campus_quicksplit_box');
  
  runApp(const CampusQuickSplitApp());
}

class CampusQuickSplitApp extends StatefulWidget {
  const CampusQuickSplitApp({super.key});

  @override
  State<CampusQuickSplitApp> createState() => _CampusQuickSplitAppState();
}

class _CampusQuickSplitAppState extends State<CampusQuickSplitApp> {
  late Box _box;
  bool isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('campus_quicksplit_box');
    isDarkMode = _box.get('isDarkMode', defaultValue: true);
  }

  void _toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    _box.put('isDarkMode', isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus QuickSplit',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
      ),
      home: HomeScreen(
        isDarkMode: isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> participants = [];
  final List<Expense> expenses = [];
  final TextEditingController _participantController = TextEditingController();
  late Box _hiveBox;

  @override
  void initState() {
    super.initState();
    _hiveBox = Hive.box('campus_quicksplit_box');
    _loadFromHive();
  }

  void _loadFromHive() {
    final savedMembers = _hiveBox.get('members');
    if (savedMembers != null) {
      setState(() {
        participants.clear();
        participants.addAll(List<String>.from(savedMembers));
      });
    }

    final savedExpensesRaw = _hiveBox.get('expenses');
    if (savedExpensesRaw != null) {
      final List<dynamic> decoded = jsonDecode(savedExpensesRaw);
      setState(() {
        expenses.clear();
        expenses.addAll(
          decoded.map((e) => Expense.fromMap(Map<String, dynamic>.from(e))),
        );
      });
    }
  }

  void _saveToHive() {
    _hiveBox.put('members', participants);
    final List<Map<String, dynamic>> mapList = expenses.map((e) => e.toMap()).toList();
    _hiveBox.put('expenses', jsonEncode(mapList));
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Group Data?'),
        content: const Text('This will delete all saved members, expenses, and settlements from Hive storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                participants.clear();
                expenses.clear();
              });
              _hiveBox.clear();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data successfully cleared.')),
              );
            },
            child: const Text('Reset Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  double get _totalGroupSpending {
    return expenses.fold(0.0, (sum, e) => sum + e.totalAmount);
  }

  double _getPaidAmount(String person) {
    return expenses.fold(0.0, (sum, e) => sum + (e.paidByMap[person] ?? 0.0));
  }

  Map<String, double> get _netBalances {
    Map<String, double> balances = {for (var p in participants) p: 0.0};

    for (var expense in expenses) {
      expense.paidByMap.forEach((payer, amountPaid) {
        balances[payer] = (balances[payer] ?? 0.0) + amountPaid;
      });

      try {
        Map<String, double> splits = SplitCalculator.calculateSplits(
          totalAmount: expense.totalAmount,
          participants: participants,
          splitType: expense.splitType,
          inputValues: expense.participantValues,
        );

        splits.forEach((person, share) {
          balances[person] = (balances[person] ?? 0.0) - share;
        });
      } catch (_) {}
    }

    return balances;
  }

  void _addParticipant() {
    final name = _participantController.text.trim();
    if (name.isNotEmpty && !participants.contains(name)) {
      setState(() {
        participants.add(name);
        _participantController.clear();
      });
      _saveToHive();
    }
  }

  void _removeParticipant(String name) {
    setState(() {
      participants.remove(name);
      expenses.removeWhere((e) => e.paidByMap.containsKey(name));
    });
    _saveToHive();
  }

  void _deleteExpenseWithUndo(Expense expense, int targetIndex) {
    setState(() {
      expenses.removeAt(targetIndex);
    });
    _saveToHive();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${expense.title}"'),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.amber,
          onPressed: () {
            setState(() {
              expenses.insert(targetIndex, expense);
            });
            _saveToHive();
          },
        ),
      ),
    );
  }

  void _showExpenseDialog({Expense? expenseToEdit}) {
    if (participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 2 group members first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isEditing = expenseToEdit != null;
    final titleController = TextEditingController(text: isEditing ? expenseToEdit.title : '');
    final amountController = TextEditingController(
      text: isEditing ? expenseToEdit.totalAmount.toString() : '',
    );
    
    SplitType selectedSplitType = isEditing ? expenseToEdit.splitType : SplitType.uniform;

    Map<String, TextEditingController> paidControllers = {
      for (var p in participants)
        p: TextEditingController(
          text: isEditing && expenseToEdit.paidByMap.containsKey(p)
              ? expenseToEdit.paidByMap[p].toString()
              : '',
        )
    };

    Map<String, TextEditingController> customControllers = {
      for (var p in participants)
        p: TextEditingController(
          text: isEditing && expenseToEdit.participantValues.containsKey(p)
              ? expenseToEdit.participantValues[p].toString()
              : '',
        )
    };
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Expense' : 'Add Campus Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Expense Title (e.g. Canteen, Chai, Books)',
                  ),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total Amount (₹)',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('Upfront Paid Amounts (Who Paid What?):', style: TextStyle(fontWeight: FontWeight.bold)),
                ...participants.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextField(
                      controller: paidControllers[p],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '$p Paid (₹)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SplitType>(
                  initialValue: selectedSplitType,
                  decoration: const InputDecoration(labelText: 'Split Strategy'),
                  items: const [
                    DropdownMenuItem(
                      value: SplitType.uniform,
                      child: Text('Equal Split (Uniform)'),
                    ),
                    DropdownMenuItem(
                      value: SplitType.exact,
                      child: Text('Exact Amounts (₹)'),
                    ),
                    DropdownMenuItem(
                      value: SplitType.ratio,
                      child: Text('Percentage Split (% Cap 100)'),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedSplitType = val!),
                ),
                if (selectedSplitType != SplitType.uniform) ...[
                  const SizedBox(height: 12),
                  if (selectedSplitType == SplitType.exact) ...[
                    Builder(
                      builder: (context) {
                        final total = double.tryParse(amountController.text.replaceAll('₹', '').trim()) ?? 0.0;
                        final allocated = participants.fold(0.0, (sum, p) {
                          final val = double.tryParse(customControllers[p]?.text.replaceAll('₹', '').trim() ?? '') ?? 0.0;
                          return sum + val;
                        });
                        final remaining = total - allocated;
                        return Text(
                          'Unallocated Remaining: ₹${remaining.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: remaining == 0 ? Colors.green : Colors.orange,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    selectedSplitType == SplitType.exact
                        ? 'Enter exact amount (₹) per person:'
                        : 'Enter percentage share (%) per person (Sum = 100%):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...participants.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: TextField(
                        controller: customControllers[p],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: selectedSplitType == SplitType.ratio ? '$p\'s Share (%)' : '$p\'s Share (₹)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final cleanAmountText = amountController.text
                    .replaceAll('₹', '')
                    .replaceAll('\$', '')
                    .trim();
                final double? amount = double.tryParse(cleanAmountText);

                if (title.isEmpty) {
                  setDialogState(() => errorMessage = 'Please enter an expense title.');
                  return;
                }
                if (amount == null || amount <= 0) {
                  setDialogState(() => errorMessage = 'Please enter a valid numeric amount.');
                  return;
                }

                Map<String, double> paidByMap = {};
                for (var p in participants) {
                  final valText = paidControllers[p]?.text.replaceAll('₹', '').trim() ?? '';
                  final val = double.tryParse(valText) ?? 0.0;
                  if (val > 0) paidByMap[p] = val;
                }

                if (paidByMap.isEmpty) {
                  paidByMap[participants.first] = amount;
                }

                double sumPaid = paidByMap.values.fold(0.0, (s, v) => s + v);
                if ((sumPaid - amount).abs() > 0.01) {
                  setDialogState(() => errorMessage = 'Upfront paid amounts (₹${sumPaid.toStringAsFixed(2)}) must equal total amount (₹${amount.toStringAsFixed(2)}).');
                  return;
                }

                Map<String, double> participantValues = {};
                if (selectedSplitType != SplitType.uniform) {
                  for (var p in participants) {
                    final valText = customControllers[p]?.text
                            .replaceAll('₹', '')
                            .replaceAll('%', '')
                            .trim() ??
                        '';
                    final val = double.tryParse(valText) ?? 0.0;
                    participantValues[p] = val;
                  }
                } else {
                  for (var p in participants) {
                    participantValues[p] = 1.0;
                  }
                }

                if (selectedSplitType == SplitType.exact) {
                  double sumAllocated = participantValues.values.fold(0.0, (s, v) => s + v);
                  if ((sumAllocated - amount).abs() > 0.01) {
                    setDialogState(() => errorMessage = 'Exact allocations (₹${sumAllocated.toStringAsFixed(2)}) must equal total amount (₹${amount.toStringAsFixed(2)}).');
                    return;
                  }
                }

                if (selectedSplitType == SplitType.ratio) {
                  double pctSum = participantValues.values.fold(0.0, (s, v) => s + v);
                  if ((pctSum - 100.0).abs() > 0.01) {
                    setDialogState(() => errorMessage = 'Percentages must sum to 100%. Current: ${pctSum.toStringAsFixed(1)}%');
                    return;
                  }
                }

                setState(() {
                  if (isEditing) {
                    final index = expenses.indexWhere((e) => e.id == expenseToEdit.id);
                    if (index != -1) {
                      expenses[index] = Expense(
                        id: expenseToEdit.id,
                        title: title,
                        totalAmount: amount,
                        paidByMap: paidByMap,
                        splitType: selectedSplitType,
                        participantValues: participantValues,
                      );
                    }
                  } else {
                    expenses.add(
                      Expense(
                        id: DateTime.now().toString(),
                        title: title,
                        totalAmount: amount,
                        paidByMap: paidByMap,
                        splitType: selectedSplitType,
                        participantValues: participantValues,
                      ),
                    );
                  }
                });

                _saveToHive();
                Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Expense'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Settlement> simplifiedSettlements = MinCashFlowCalculator.simplifyDebts(_netBalances);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus QuickSplit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Reset All Data',
            onPressed: _clearAllData,
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Group Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _participantController,
                          decoration: const InputDecoration(
                            labelText: 'Member Name (e.g. Rahul, Priya)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addParticipant(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addParticipant,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (participants.isEmpty)
                    const Text(
                      'No members added yet. Type a name above to start!',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: participants
                          .map(
                            (person) => Chip(
                              label: Text(person),
                              onDeleted: () => _removeParticipant(person),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Spending Analytics',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: ₹${_totalGroupSpending.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (participants.isEmpty || expenses.isEmpty)
                    const Text(
                      'Add members and expenses to view spending distribution.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...participants.map((person) {
                      final paid = _getPaidAmount(person);
                      final sharePct = _totalGroupSpending > 0 ? (paid / _totalGroupSpending) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(person, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('₹${paid.toStringAsFixed(2)} (${(sharePct * 100).toStringAsFixed(1)}%)'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: sharePct,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Balances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (participants.isEmpty)
                    const Text('Add group members to view balances.')
                  else
                    ..._netBalances.entries.map(
                      (e) => Text(
                        '${e.key}: ${e.value >= 0 ? "+" : ""}₹${e.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: e.value > 0 ? Colors.green : (e.value < 0 ? Colors.red : Colors.grey),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Simplified Debt Settlements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (simplifiedSettlements.isEmpty)
                    const Text('All debts are settled!')
                  else
                    ...simplifiedSettlements.map(
                      (s) => ListTile(
                        leading: const Icon(Icons.arrow_forward, color: Colors.orange),
                        title: Text('${s.sender} owes ${s.receiver}'),
                        trailing: Text('₹${s.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Text('Logged Expenses (Swipe to delete)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            const Center(child: Text('No expenses added yet.'))
          else
            ...expenses.asMap().entries.map(
              (entry) {
                final idx = entry.key;
                final e = entry.value;
                return Dismissible(
                  key: Key(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteExpenseWithUndo(e, idx),
                  child: Card(
                    child: ListTile(
                      title: Text(e.title),
                      subtitle: Text('Paid by ${e.primaryPaidBySummary} (${e.splitType.name})'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${e.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                            onPressed: () => _showExpenseDialog(expenseToEdit: e),
                            tooltip: 'Edit Expense',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}