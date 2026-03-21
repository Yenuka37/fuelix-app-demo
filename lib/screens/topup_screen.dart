import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/topup_model.dart';
import '../database/db_helper.dart';
import '../widgets/custom_button.dart';

// ─── Quick-amount presets (LKR) ───────────────────────────────────────────────
const _kPresets = [500.0, 1000.0, 2000.0, 5000.0, 10000.0];

// ─── Payment methods ──────────────────────────────────────────────────────────
const _kMethods = [
  _PayMethod('Credit / Debit Card', Icons.credit_card_rounded, AppColors.ocean),
  _PayMethod('Bank Transfer', Icons.account_balance_rounded, AppColors.emerald),
  _PayMethod('Mobile Pay', Icons.phone_android_rounded, AppColors.amber),
];

class _PayMethod {
  final String label;
  final IconData icon;
  final Color color;
  const _PayMethod(this.label, this.icon, this.color);
}

// ═════════════════════════════════════════════════════════════════════════════
// TopUpScreen
// ═════════════════════════════════════════════════════════════════════════════
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});
  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen>
    with SingleTickerProviderStateMixin {
  final _db = DbHelper();
  UserModel? _user;
  WalletModel? _wallet;
  List<TopUpTransactionModel> _history = [];

  bool _loadingWallet = true;
  bool _processing = false;

  double? _selectedAmount;
  final _customCtrl = TextEditingController();
  int _selectedMethod = 0; // index into _kMethods

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ── Tab: 0=Top Up, 1=History ──────────────────────────────────────────────
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final u = ModalRoute.of(context)?.settings.arguments as UserModel?;
    if (_user == null && u != null) {
      _user = u;
      _loadData();
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_user?.id == null) {
      setState(() => _loadingWallet = false);
      return;
    }
    final w = await _db.getWallet(_user!.id!);
    final h = await _db.getTopUpHistory(_user!.id!);
    if (mounted) {
      setState(() {
        _wallet = w;
        _history = h;
        _loadingWallet = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  // ── Derive effective amount ───────────────────────────────────────────────
  double? get _effectiveAmount {
    if (_selectedAmount != null) return _selectedAmount;
    final v = double.tryParse(_customCtrl.text.trim());
    if (v != null && v >= 100) return v;
    return null;
  }

  // ── Process top-up ────────────────────────────────────────────────────────
  Future<void> _processTopUp() async {
    final amount = _effectiveAmount;
    if (amount == null) {
      showAppSnackbar(
        context,
        message: 'Enter or select a valid amount (min LKR 100).',
        isError: true,
      );
      return;
    }

    setState(() => _processing = true);

    final tx = await _db.processTopUp(
      userId: _user!.id!,
      amount: amount,
      method: _kMethods[_selectedMethod].label,
    );

    if (!mounted) return;

    if (tx != null) {
      await _loadData();
      setState(() {
        _selectedAmount = null;
        _customCtrl.clear();
        _tab = 1;
      });
      _showSuccessSheet(amount);
    } else {
      showAppSnackbar(
        context,
        message: 'Top-up failed. Please try again.',
        isError: true,
      );
    }

    setState(() => _processing = false);
  }

  void _showSuccessSheet(double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        amount: amount,
        balance: _wallet?.balance ?? 0,
        isDark: isDark,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF0A1628)]
                : [const Color(0xFFF0FDF8), const Color(0xFFEFF6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _iconBox(Icons.arrow_back_ios_new_rounded, isDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Wallet & Top Up',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Wallet balance card ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _WalletBalanceCard(
                  wallet: _wallet,
                  loading: _loadingWallet,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 20),

              // ── Tab bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TabBar(
                  selected: _tab,
                  isDark: isDark,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 20),

              // ── Content ────────────────────────────────────────────────
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _tab == 0
                      ? _TopUpForm(
                          isDark: isDark,
                          selectedAmount: _selectedAmount,
                          customCtrl: _customCtrl,
                          selectedMethod: _selectedMethod,
                          processing: _processing,
                          onPreset: (a) => setState(() {
                            _selectedAmount = a;
                            _customCtrl.clear();
                          }),
                          onClearPreset: () =>
                              setState(() => _selectedAmount = null),
                          onMethodSelect: (i) =>
                              setState(() => _selectedMethod = i),
                          onTopUp: _processTopUp,
                        )
                      : _HistoryList(history: _history, isDark: isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, bool isDark) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    ),
    child: Icon(
      icon,
      size: 16,
      color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Wallet Balance Card
// ═════════════════════════════════════════════════════════════════════════════
class _WalletBalanceCard extends StatelessWidget {
  final WalletModel? wallet;
  final bool loading, isDark;
  const _WalletBalanceCard({
    required this.wallet,
    required this.loading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF0A84FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: Colors.white.withOpacity(0.18),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fuelix Wallet',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Available Balance',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Verified badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Secure',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Balance display
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  wallet?.formattedBalance ?? 'LKR 0.00',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            'Fuelix fuel credits',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab Bar
// ═════════════════════════════════════════════════════════════════════════════
class _TabBar extends StatelessWidget {
  final int selected;
  final bool isDark;
  final ValueChanged<int> onSelect;
  const _TabBar({
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'Top Up',
            index: 0,
            selected: selected,
            isDark: isDark,
            onTap: onSelect,
          ),
          _TabItem(
            label: 'History',
            index: 1,
            selected: selected,
            isDark: isDark,
            onTap: onSelect,
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int index, selected;
  final bool isDark;
  final ValueChanged<int> onTap;
  const _TabItem({
    required this.label,
    required this.index,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF0A84FF)],
                  )
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Top Up Form
// ═════════════════════════════════════════════════════════════════════════════
class _TopUpForm extends StatelessWidget {
  final bool isDark, processing;
  final double? selectedAmount;
  final TextEditingController customCtrl;
  final int selectedMethod;
  final ValueChanged<double> onPreset;
  final VoidCallback onClearPreset;
  final ValueChanged<int> onMethodSelect;
  final VoidCallback onTopUp;

  const _TopUpForm({
    required this.isDark,
    required this.processing,
    required this.selectedAmount,
    required this.customCtrl,
    required this.selectedMethod,
    required this.onPreset,
    required this.onClearPreset,
    required this.onMethodSelect,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Amount section ────────────────────────────────────────────
          _SectionLabel('Select Amount', isDark),
          // Preset chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kPresets.map((a) {
              final selected = a == selectedAmount;
              return GestureDetector(
                onTap: () => onPreset(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF0A84FF)],
                          )
                        : null,
                    color: selected
                        ? null
                        : (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'LKR ${a.toStringAsFixed(0)}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : (isDark ? AppColors.darkText : AppColors.lightText),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Custom amount input
          _CustomAmountField(
            controller: customCtrl,
            isDark: isDark,
            onChanged: (_) => onClearPreset(),
          ),
          const SizedBox(height: 24),

          // ── Payment method ────────────────────────────────────────────
          _SectionLabel('Payment Method', isDark),
          Column(
            children: List.generate(_kMethods.length, (i) {
              final method = _kMethods[i];
              final sel = i == selectedMethod;
              return GestureDetector(
                onTap: () => onMethodSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: sel
                        ? method.color.withOpacity(isDark ? 0.14 : 0.08)
                        : (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface),
                    border: Border.all(
                      color: sel
                          ? method.color.withOpacity(0.5)
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: method.color.withOpacity(isDark ? 0.18 : 0.10),
                        ),
                        child: Icon(method.icon, size: 20, color: method.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          method.label,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? method.color
                                : (isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel
                                ? method.color
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            width: 2,
                          ),
                          color: sel ? method.color : Colors.transparent,
                        ),
                        child: sel
                            ? const Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // ── Info notice ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.ocean.withOpacity(isDark ? 0.08 : 0.05),
              border: Border.all(color: AppColors.ocean.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppColors.ocean,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Top-up credits are added instantly to your Fuelix Wallet. '
                    'Credits can be used to pay at partnered fuel stations '
                    'via your vehicle Fuel Pass.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.ocean,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Top-up button ─────────────────────────────────────────────
          GradientButton(
            label: 'Top Up Now',
            onPressed: onTopUp,
            isLoading: processing,
            colors: const [Color(0xFF7C3AED), Color(0xFF0A84FF)],
          ),
        ],
      ),
    );
  }
}

// ─── Custom amount field ──────────────────────────────────────────────────────
class _CustomAmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;
  const _CustomAmountField({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final hintColor = isDark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      decoration: InputDecoration(
        hintText: 'Or enter custom amount',
        hintStyle: GoogleFonts.inter(fontSize: 14, color: hintColor),
        prefixText: 'LKR  ',
        prefixStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF7C3AED),
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Transaction History List
// ═════════════════════════════════════════════════════════════════════════════
class _HistoryList extends StatelessWidget {
  final List<TopUpTransactionModel> history;
  final bool isDark;
  const _HistoryList({required this.history, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.15),
                    AppColors.ocean.withOpacity(0.15),
                  ],
                ),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your top-up history will appear here.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TransactionTile(tx: history[i], isDark: isDark),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TopUpTransactionModel tx;
  final bool isDark;
  const _TransactionTile({required this.tx, required this.isDark});

  IconData _methodIcon(String method) {
    if (method.contains('Card')) return Icons.credit_card_rounded;
    if (method.contains('Bank')) return Icons.account_balance_rounded;
    if (method.contains('Mobile')) return Icons.phone_android_rounded;
    return Icons.payment_rounded;
  }

  Color _methodColor(String method) {
    if (method.contains('Card')) return AppColors.ocean;
    if (method.contains('Bank')) return AppColors.emerald;
    if (method.contains('Mobile')) return AppColors.amber;
    return const Color(0xFF7C3AED);
  }

  String _formatDate(DateTime d) {
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${mo[d.month - 1]} ${d.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final color = _methodColor(tx.method);
    final isOk = tx.status == TopUpStatus.completed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Method icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(isDark ? 0.15 : 0.08),
            ),
            child: Icon(_methodIcon(tx.method), size: 20, color: color),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.method,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(tx.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                if (tx.reference != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Ref: ${tx.reference}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Amount + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+LKR ${tx.amount.toStringAsFixed(2)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isOk ? AppColors.emerald : AppColors.error,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: (isOk ? AppColors.emerald : AppColors.error)
                      .withOpacity(isDark ? 0.15 : 0.08),
                ),
                child: Text(
                  tx.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isOk ? AppColors.emerald : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Success Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════
class _SuccessSheet extends StatelessWidget {
  final double amount, balance;
  final bool isDark;
  const _SuccessSheet({
    required this.amount,
    required this.balance,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          const SizedBox(height: 32),
          // Checkmark
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.emerald, AppColors.ocean],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Top Up Successful!',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LKR ${amount.toStringAsFixed(2)} has been added\nto your Fuelix Wallet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.emerald.withOpacity(isDark ? 0.12 : 0.07),
              border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Balance',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextSub
                        : AppColors.lightTextSub,
                  ),
                ),
                Text(
                  'LKR ${balance.toStringAsFixed(2)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Done',
            onPressed: () => Navigator.pop(context),
            colors: const [Color(0xFF7C3AED), Color(0xFF0A84FF)],
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        letterSpacing: 0.5,
      ),
    ),
  );
}
