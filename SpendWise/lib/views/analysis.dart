import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/transaction_controller.dart';
import '../models/transaction.dart';
import '../themes/app_theme.dart';
import '../services/api_service.dart';
import '../main.dart'; // ── NEW: IMPORT FOR CURRENCY NOTIFIER ──

class AnalysisPage extends StatefulWidget {
  final TransactionController controller;
  final VoidCallback onBackToHome;

  const AnalysisPage({
    super.key,
    required this.controller,
    required this.onBackToHome,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String _selectedPeriod = '1M';
  final List<String> _periods = ['1W', '1M', '3M', '6M', '1Y']; 
  
  Set<String> _activeLines = {'Income', 'Expense'}; 
  
  int _touchedDonutIndex = -1;
  bool _isGeneratingInsights = false;
  List<String> _aiInsights = [];

  List<String> get _availableCategories {
    return widget.controller.allTransactions
        .where((t) => t.isExpense)
        .map((t) => t.category)
        .toSet()
        .toList()..sort();
  }

  List<Transaction> get _filteredTransactions {
    final now = DateTime.now();
    DateTime cutoff;
    
    switch (_selectedPeriod) {
      case '1W': 
        int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
        cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract)); 
        break;
      case '1M': cutoff = DateTime(now.year, now.month - 1, now.day); break;
      case '3M': cutoff = DateTime(now.year, now.month - 3, now.day); break;
      case '6M': cutoff = DateTime(now.year, now.month - 6, now.day); break;
      case '1Y': cutoff = DateTime(now.year - 1, now.month, now.day); break;
      default: cutoff = DateTime(now.year, now.month - 1, now.day);
    }
    
    return widget.controller.allTransactions.where((t) => t.date.isAfter(cutoff) || t.date.isAtSameMomentAs(cutoff)).toList();
  }

  Map<String, double> get _categorySpends {
    Map<String, double> spends = {};
    for (var t in _filteredTransactions.where((t) => t.isExpense)) {
      spends[t.category] = (spends[t.category] ?? 0) + t.amount;
    }
    var sortedEntries = spends.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  Future<void> _generateInsights() async {
    setState(() => _isGeneratingInsights = true);
    
    // ── Grab the active currency from the global notifier ──
    final currentCurrency = currencyNotifier.value; 
    
    // Pass the currency to the API
    final insights = await ApiService.getAiInsights(currentCurrency);
    
    if (mounted) {
      setState(() {
        _aiInsights = insights;
        _isGeneratingInsights = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).cardColor;
    const textColor = Colors.white;
    
    final expenses = _categorySpends;
    final totalExpense = expenses.values.fold(0.0, (a, b) => a + b);

    // ── NEW: WRAP ENTIRE PAGE IN CURRENCY BUILDER ──
    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, currency, child) {
        final sym = currency.split(' ')[0]; // Extracts the symbol (e.g. '$')

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBackToHome),
            title: const Text('Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _periods.length,
                    itemBuilder: (context, index) {
                      final period = _periods[index];
                      final isSelected = _selectedPeriod == period;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedPeriod = period;
                          _touchedDonutIndex = -1; 
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppTheme.primaryGradient : null,
                            color: isSelected ? null : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              period,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.jadeLight.withOpacity(0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: AppTheme.jadeLight.withOpacity(0.05), blurRadius: 20)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppTheme.jadeLight, size: 20),
                          SizedBox(width: 8),
                          Text('Magic Insights', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (_aiInsights.isEmpty && !_isGeneratingInsights)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _generateInsights,
                            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                            label: const Text('Generate Financial Report', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.jadeDark),
                          ),
                        )
                      else if (_isGeneratingInsights)
                        const Center(child: CircularProgressIndicator(color: AppTheme.jadeLight))
                      else
                        ..._aiInsights.map((insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('✨ ', style: TextStyle(fontSize: 16)),
                              Expanded(child: Text(insight, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4))),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    
                    InkWell(
                      onTap: _showLineFilterDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.timeline, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Plot Lines', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_activeLines.isEmpty)
                   const Text('Tap "Plot Lines" to visualize data.', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))
                else
                   Wrap(
                     spacing: 16,
                     runSpacing: 12,
                     children: _activeLines.map((name) {
                       return Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Container(width: 10, height: 10, decoration: BoxDecoration(color: _getLineColor(name), shape: BoxShape.circle)),
                           const SizedBox(width: 6),
                           Text(name == 'Expense' ? 'Total Out' : name == 'Income' ? 'Total In' : name, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                         ],
                       );
                     }).toList(),
                   ),
                   
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
                  // ── PASS SYMBOL DOWN TO THE CHART ──
                  child: _buildTrendChart(sym),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expense Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    Row(
                      children: [
                        Icon(Icons.touch_app, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('Tap a slice', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
                  child: expenses.isEmpty
                      ? const Center(child: Text('No expenses in this period.', style: TextStyle(color: Colors.white54)))
                      : AspectRatio(
                          aspectRatio: 1.3,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                          _touchedDonutIndex = -1;
                                          return;
                                        }
                                        _touchedDonutIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 60,
                                  sections: _showingSections(expenses),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _touchedDonutIndex == -1 || _touchedDonutIndex >= expenses.length
                                        ? 'Total'
                                        : expenses.keys.elementAt(_touchedDonutIndex),
                                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  // ── DONUT TEXT FIXED TO USE $sym ──
                                  Text(
                                    '$sym${(_touchedDonutIndex == -1 || _touchedDonutIndex >= expenses.length 
                                          ? totalExpense 
                                          : expenses.values.elementAt(_touchedDonutIndex)).toStringAsFixed(0)}',
                                    style: const TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 32),

                const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 16),
                
                ...expenses.entries.map((entry) {
                  final percentage = totalExpense > 0 ? (entry.value / totalExpense) : 0.0;
                  final categoryColor = _getLineColor(entry.key); 
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            // ── CATEGORY SPEND FIXED TO USE $sym ──
                            Text('$sym${entry.value.toStringAsFixed(0)}', style: const TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLineFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cats = _availableCategories;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        Icon(Icons.stacked_line_chart, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Select Trends', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _checkboxTile('Income', setSheetState),
                          _checkboxTile('Expense', setSheetState),
                          if (cats.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                              child: Divider(color: Colors.white12),
                            ),
                            ...cats.map((c) => _checkboxTile(c, setSheetState)),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _checkboxTile(String name, StateSetter setSheetState) {
    final isSelected = _activeLines.contains(name);
    return CheckboxListTile(
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      value: isSelected,
      activeColor: _getLineColor(name),
      checkColor: Colors.white,
      side: const BorderSide(color: Colors.white54),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onChanged: (val) {
        if (val == null) return;
        
        setSheetState(() {
          if (val) _activeLines.add(name);
          else _activeLines.remove(name);
        });
        
        setState(() {});
      },
    );
  }

  // ── CHART WIDGET UPDATED TO ACCEPT DYNAMIC CURRENCY SYMBOL ──
  Widget _buildTrendChart(String sym) {
    final cardBg = Theme.of(context).cardColor; 
    final now = DateTime.now();
    int buckets = 0;
    double daysPerBucket = 1.0;
    DateTime cutoff = now;
    List<String> xLabels = [];

    switch (_selectedPeriod) {
      case '1W': 
        buckets = 7;
        daysPerBucket = 1.0;
        int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
        cutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract)); 
        xLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        break;
      case '1M': 
        buckets = 4;
        daysPerBucket = 30.0 / 4;
        cutoff = now.subtract(const Duration(days: 30));
        for (int i = 0; i < buckets; i++) xLabels.add('Wk ${i + 1}');
        break;
      case '3M': 
        buckets = 12;
        daysPerBucket = 90.0 / 12;
        cutoff = now.subtract(const Duration(days: 90));
        for (int i = 0; i < buckets; i++) xLabels.add('W${i + 1}');
        break;
      case '6M': 
        buckets = 12;
        daysPerBucket = 180.0 / 12;
        cutoff = now.subtract(const Duration(days: 180));
        for (int i = 0; i < buckets; i++) xLabels.add('P${i + 1}');
        break;
      case '1Y': 
        buckets = 12;
        cutoff = DateTime(now.year - 1, now.month + 1, 1);
        List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        for (int i = 0; i < buckets; i++) xLabels.add(months[(cutoff.month - 1 + i) % 12]);
        break;
    }

    Map<String, List<FlSpot>> linesSpots = {};
    for (var name in _activeLines) linesSpots[name] = [];
    
    double maxAmount = 100.0; 

    for (int i = 0; i < buckets; i++) {
      DateTime start;
      DateTime end;

      if (_selectedPeriod == '1Y') {
        start = DateTime(cutoff.year, cutoff.month + i, 1);
        end = DateTime(cutoff.year, cutoff.month + i + 1, 1);
      } else {
        start = cutoff.add(Duration(days: (i * daysPerBucket).round()));
        end = cutoff.add(Duration(days: ((i + 1) * daysPerBucket).round()));
        if (i == buckets - 1 && _selectedPeriod != '1W') end = now.add(const Duration(days: 1)); 
      }

      Map<String, double> bucketTotals = {};
      for (var name in _activeLines) bucketTotals[name] = 0.0;

      for (var t in widget.controller.allTransactions) {
        if ((t.date.isAfter(start) || t.date.isAtSameMomentAs(start)) && t.date.isBefore(end)) {
          if (!t.isExpense && _activeLines.contains('Income')) {
            bucketTotals['Income'] = bucketTotals['Income']! + t.amount;
          }
          if (t.isExpense) {
            if (_activeLines.contains('Expense')) {
              bucketTotals['Expense'] = bucketTotals['Expense']! + t.amount;
            }
            if (_activeLines.contains(t.category)) {
              bucketTotals[t.category] = bucketTotals[t.category]! + t.amount;
            }
          }
        }
      }
      
      for (var name in _activeLines) {
        final val = bucketTotals[name]!;
        linesSpots[name]!.add(FlSpot(i.toDouble(), val));
        if (val > maxAmount) maxAmount = val;
      }
    }

    double chartWidth = buckets * 60.0; 

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Container(
            width: chartWidth > constraints.maxWidth ? chartWidth : constraints.maxWidth,
            padding: const EdgeInsets.only(right: 24, left: 12, top: 40), 
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          // ── TOOLTIP FIXED TO USE $sym ──
                          '$sym${spot.y.toStringAsFixed(0)}',
                          TextStyle(
                            color: spot.bar.color ?? Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 13
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true, drawVerticalLine: false, horizontalInterval: maxAmount / 4,
                  getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1),
                ),
                minX: 0, 
                maxX: (buckets - 1).toDouble(), 
                minY: 0, 
                maxY: maxAmount * 1.4, 
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42, 
                      interval: maxAmount / 4, 
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink(); 
                        
                        String text;
                        if (value >= 1000000) {
                          text = '${(value / 1000000).toStringAsFixed(1)}M';
                        } else if (value >= 1000) {
                          text = '${(value / 1000).toStringAsFixed(1)}k';
                        } else {
                          text = value.toStringAsFixed(0);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            text, 
                            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, interval: 1, reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= xLabels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(xLabels[index], style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: _activeLines.map((name) {
                  final color = _getLineColor(name);
                  return LineChartBarData(
                    spots: linesSpots[name]!,
                    isCurved: true, curveSmoothness: 0.35, color: color, barWidth: 3, isStrokeCapRound: true,
                    dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 2, strokeColor: cardBg)),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      }
    );
  }

  List<PieChartSectionData> _showingSections(Map<String, double> expenses) {
    return List.generate(expenses.length, (i) {
      final isTouched = i == _touchedDonutIndex;
      final radius = isTouched ? 40.0 : 30.0;
      final value = expenses.values.elementAt(i);
      final color = _getDonutColor(i);

      return PieChartSectionData(
        color: color,
        value: value,
        title: '', 
        radius: radius,
        badgeWidget: isTouched 
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
              child: Icon(_getIconForCategory(expenses.keys.elementAt(i)), size: 16, color: color),
            ) 
          : null,
        badgePositionPercentageOffset: .98,
      );
    });
  }

  Color _getLineColor(String name) {
    if (name == 'Income') return AppTheme.jadeLight;
    if (name == 'Expense') return Colors.redAccent;
    
    final colors = [
      const Color(0xFF0F766E),     
      const Color(0xFFFFC300),     
      const Color(0xFF4A00E0),     
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.lightBlue,
    ];
    int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  Color _getDonutColor(int index) {
    final colors = [
      AppTheme.jadeLight, const Color(0xFF0F766E), const Color(0xFFFFC300),
      const Color(0xFF4A00E0), const Color(0xFFE53935), Colors.blueAccent, Colors.orangeAccent,
    ];
    return colors[index % colors.length];
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'entertainment': return Icons.movie;
      case 'shopping': return Icons.shopping_bag;
      case 'bills': return Icons.receipt;
      default: return Icons.category;
    }
  }
}