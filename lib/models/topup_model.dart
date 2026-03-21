enum TopUpStatus { pending, completed, failed }

class WalletModel {
  final int userId;
  final double balance; // current balance in LKR
  final DateTime? updatedAt;

  const WalletModel({
    required this.userId,
    required this.balance,
    this.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> m) => WalletModel(
    userId: m['user_id'] as int,
    balance: (m['balance'] as num).toDouble(),
    updatedAt: m['updated_at'] != null
        ? DateTime.tryParse(m['updated_at'] as String)
        : null,
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'balance': balance,
    'updated_at':
        updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  String get formattedBalance => 'LKR ${balance.toStringAsFixed(2)}';
}

class TopUpTransactionModel {
  final int? id;
  final int userId;
  final double amount; // LKR
  final String method; // Card, Bank Transfer, Mobile Pay
  final TopUpStatus status;
  final String? reference; // payment reference / receipt no
  final DateTime createdAt;

  TopUpTransactionModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    this.reference,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get statusLabel {
    switch (status) {
      case TopUpStatus.pending:
        return 'Pending';
      case TopUpStatus.completed:
        return 'Completed';
      case TopUpStatus.failed:
        return 'Failed';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'amount': amount,
    'method': method,
    'status': status.name,
    'reference': reference,
    'created_at': createdAt.toIso8601String(),
  };

  factory TopUpTransactionModel.fromMap(Map<String, dynamic> m) =>
      TopUpTransactionModel(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        method: m['method'] as String,
        status: TopUpStatus.values.firstWhere(
          (s) => s.name == (m['status'] as String),
          orElse: () => TopUpStatus.pending,
        ),
        reference: m['reference'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
