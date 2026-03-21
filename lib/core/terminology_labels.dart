enum TransactionTerm {
  income,
  expense,
  transfer,
  creditExpense,
  liabilityPayment,
  advancePayment,
  reimbursement,
}

enum DirectionTerm {
  increase,
  decrease,
}

enum EntryTerm {
  first,
  second,
}

enum StatusTerm {
  posted,
  pending,
  voided,
  periodOpen,
  periodClosed,
}

enum SectionTerm {
  basicInfo,
  entries,
  overview,
  operations,
}

enum ActionTerm {
  save,
  edit,
  back,
  duplicate,
  correction,
  cancel,
  voidAction,
  refund,
  refundFull,
  refundPartial,
}

enum FieldTerm {
  transactionDate,
  transactionType,
  description,
  counterparty,
  externalRef,
  amount,
  memo,
  account,
  direction,
}

enum AccountKindTerm {
  asset,
  liability,
  income,
  expense,
}

enum PointsDirectionTerm {
  earned,
  redeemed,
  expired,
  adjusted,
}

enum PointsTerm {
  pointsAccount,
  pointsBalance,
  pointsHistory,
  earnPoints,
  redeemPoints,
  expirePoints,
  adjustPoints,
}

class TerminologyLabels {
  TerminologyLabels._();

  static const Map<TransactionTerm, Map<String, String>> transactions = {
    TransactionTerm.income: {
      'basic': 'お金が入った',
      'advanced': '収入',
    },
    TransactionTerm.expense: {
      'basic': 'お金を使った',
      'advanced': '支出',
    },
    TransactionTerm.transfer: {
      'basic': 'お金の移動',
      'advanced': '振替',
    },
    TransactionTerm.creditExpense: {
      'basic': 'カードで支払い',
      'advanced': 'カード支出',
    },
    TransactionTerm.liabilityPayment: {
      'basic': 'カードの支払い',
      'advanced': '負債返済',
    },
    TransactionTerm.advancePayment: {
      'basic': '立替',
      'advanced': '立替',
    },
    TransactionTerm.reimbursement: {
      'basic': '精算',
      'advanced': '精算',
    },
  };

  static const Map<DirectionTerm, Map<String, String>> directions = {
    DirectionTerm.increase: {
      'basic': '入',
      'advanced': '増加',
    },
    DirectionTerm.decrease: {
      'basic': '出',
      'advanced': '減少',
    },
  };

  static const Map<EntryTerm, Map<String, String>> entries = {
    EntryTerm.first: {
      'basic': '出金',
      'advanced': '明細 1 / 借方',
    },
    EntryTerm.second: {
      'basic': '入金',
      'advanced': '明細 2 / 貸方',
    },
  };

  static const Map<StatusTerm, Map<String, String>> statuses = {
    StatusTerm.posted: {
      'basic': '計上済み',
      'advanced': '計上済み',
    },
    StatusTerm.pending: {
      'basic': '保留',
      'advanced': '保留',
    },
    StatusTerm.voided: {
      'basic': '取消済み',
      'advanced': '取消済み',
    },
    StatusTerm.periodOpen: {
      'basic': '未締め',
      'advanced': '未締め',
    },
    StatusTerm.periodClosed: {
      'basic': '締め済み',
      'advanced': '締め済み',
    },
  };

  static const Map<SectionTerm, Map<String, String>> sections = {
    SectionTerm.basicInfo: {
      'basic': '基本情報',
      'advanced': '基本情報',
    },
    SectionTerm.entries: {
      'basic': '明細',
      'advanced': '明細',
    },
    SectionTerm.overview: {
      'basic': '概要',
      'advanced': '概要',
    },
    SectionTerm.operations: {
      'basic': '操作',
      'advanced': '操作',
    },
  };

  static const Map<ActionTerm, Map<String, String>> actions = {
    ActionTerm.save: {
      'basic': '保存',
      'advanced': '保存',
    },
    ActionTerm.edit: {
      'basic': '編集',
      'advanced': '編集',
    },
    ActionTerm.back: {
      'basic': '戻る',
      'advanced': '戻る',
    },
    ActionTerm.duplicate: {
      'basic': '複製',
      'advanced': '複製',
    },
    ActionTerm.correction: {
      'basic': '訂正',
      'advanced': '訂正',
    },
    ActionTerm.cancel: {
      'basic': '取消',
      'advanced': '取消',
    },
    ActionTerm.voidAction: {
      'basic': '取消',
      'advanced': '取消',
    },
    ActionTerm.refund: {
      'basic': '返金',
      'advanced': '返金',
    },
    ActionTerm.refundFull: {
      'basic': '全額返金',
      'advanced': '全額返金',
    },
    ActionTerm.refundPartial: {
      'basic': '一部返金',
      'advanced': '一部返金',
    },
  };

  static const Map<FieldTerm, Map<String, String>> fields = {
    FieldTerm.transactionDate: {
      'basic': '取引日',
      'advanced': '取引日',
    },
    FieldTerm.transactionType: {
      'basic': '取引種別',
      'advanced': '取引種別',
    },
    FieldTerm.description: {
      'basic': '説明',
      'advanced': '説明',
    },
    FieldTerm.counterparty: {
      'basic': '相手先',
      'advanced': '相手先',
    },
    FieldTerm.externalRef: {
      'basic': '外部参照',
      'advanced': '外部参照',
    },
    FieldTerm.amount: {
      'basic': '金額',
      'advanced': '金額',
    },
    FieldTerm.memo: {
      'basic': 'メモ',
      'advanced': 'メモ',
    },
    FieldTerm.account: {
      'basic': '口座',
      'advanced': '勘定',
    },
    FieldTerm.direction: {
      'basic': '方向',
      'advanced': '方向',
    },
  };

  static const Map<AccountKindTerm, Map<String, String>> accountKinds = {
    AccountKindTerm.asset: {
      'basic': '資産',
      'advanced': '資産',
    },
    AccountKindTerm.liability: {
      'basic': '負債',
      'advanced': '負債',
    },
    AccountKindTerm.income: {
      'basic': '収入',
      'advanced': '収入',
    },
    AccountKindTerm.expense: {
      'basic': '支出',
      'advanced': '支出',
    },
  };

  static const Map<PointsDirectionTerm, Map<String, String>> pointsDirections =
      {
    PointsDirectionTerm.earned: {
      'basic': '獲得',
      'advanced': 'ポイント獲得',
    },
    PointsDirectionTerm.redeemed: {
      'basic': '使用',
      'advanced': 'ポイント使用',
    },
    PointsDirectionTerm.expired: {
      'basic': '失効',
      'advanced': 'ポイント失効',
    },
    PointsDirectionTerm.adjusted: {
      'basic': '調整',
      'advanced': 'ポイント調整',
    },
  };

  static const Map<PointsTerm, Map<String, String>> points = {
    PointsTerm.pointsAccount: {
      'basic': 'ポイント口座',
      'advanced': 'ポイント口座',
    },
    PointsTerm.pointsBalance: {
      'basic': '残高',
      'advanced': 'ポイント残高',
    },
    PointsTerm.pointsHistory: {
      'basic': '履歴',
      'advanced': 'ポイント履歴',
    },
    PointsTerm.earnPoints: {
      'basic': 'ポイントをためる',
      'advanced': 'ポイント獲得',
    },
    PointsTerm.redeemPoints: {
      'basic': 'ポイントを使う',
      'advanced': 'ポイント使用',
    },
    PointsTerm.expirePoints: {
      'basic': 'ポイントを失効させる',
      'advanced': 'ポイント失効',
    },
    PointsTerm.adjustPoints: {
      'basic': 'ポイントを調整する',
      'advanced': 'ポイント調整',
    },
  };

  static const Map<String, String> tooltips = {
    '出金': '出金（しゅっきん）：借方。資産や負債の増加を記録します',
    '入金': '入金（にゅうきん）：貸方。資産や負債の減少を記録します',
    '借方': '借方（かりかた）：左側。資産の増加または負債の減少を記録します',
    '貸方': '貸方（かしかた）：右側。資産の減少または負債の増加を記録します',
    '勘定': '勘定（かんじょう）：取引を記録する科目です',
    '仕訳': '仕訳（しわけ）：取引を借方・貸方に分解して記録することです',
  };

  static const Map<String, Map<String, String>> standardAccountNames = {
    'Cash': {
      'basic': '現金',
      'advanced': 'Cash',
    },
    'Main Bank': {
      'basic': 'メインバンク',
      'advanced': 'Main Bank',
    },
    'E Money': {
      'basic': '電子マネー',
      'advanced': 'E Money',
    },
    'Savings': {
      'basic': '貯蓄',
      'advanced': 'Savings',
    },
    'Main Card': {
      'basic': 'メインカード',
      'advanced': 'Main Card',
    },
    'Other Payable': {
      'basic': 'その他支払',
      'advanced': 'Other Payable',
    },
    'Salary': {
      'basic': '給与',
      'advanced': 'Salary',
    },
    'Side Job': {
      'basic': '副業',
      'advanced': 'Side Job',
    },
    'Refund': {
      'basic': '返金',
      'advanced': 'Refund',
    },
    'Point Reward': {
      'basic': 'ポイント',
      'advanced': 'Point Reward',
    },
    'Adjustment': {
      'basic': '調整',
      'advanced': 'Adjustment',
    },
    'Food': {
      'basic': '食費',
      'advanced': 'Food',
    },
    'Housing': {
      'basic': '住居',
      'advanced': 'Housing',
    },
    'Utilities': {
      'basic': '光熱費',
      'advanced': 'Utilities',
    },
    'Communication': {
      'basic': '通信費',
      'advanced': 'Communication',
    },
    'Transport': {
      'basic': '交通費',
      'advanced': 'Transport',
    },
    'Daily Goods': {
      'basic': '日用品',
      'advanced': 'Daily Goods',
    },
    'Medical': {
      'basic': '医療',
      'advanced': 'Medical',
    },
    'Education': {
      'basic': '教育',
      'advanced': 'Education',
    },
    'Entertainment': {
      'basic': '娯楽',
      'advanced': 'Entertainment',
    },
    'Social': {
      'basic': '交的経費',
      'advanced': 'Social',
    },
    'Special': {
      'basic': '特別費',
      'advanced': 'Special',
    },
  };
}
