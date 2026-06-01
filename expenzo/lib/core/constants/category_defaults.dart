import '../enums/transaction_type.dart';

class CategoryDefault {
  final String id;
  final String name;
  final TransactionType type;
  final String iconName;
  final String colorHex;
  final int sortOrder;

  const CategoryDefault({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.colorHex,
    required this.sortOrder,
  });
}

class CategoryDefaults {
  CategoryDefaults._();

  static const List<CategoryDefault> all = [
    // ── Income ──────────────────────────────────────────────────────────────
    CategoryDefault(
      id: 'cat_income_tuition_salary',
      name: 'Tuition Salary',
      type: TransactionType.income,
      iconName: 'school',
      colorHex: '#43A047',
      sortOrder: 0,
    ),
    CategoryDefault(
      id: 'cat_income_salary',
      name: 'Salary',
      type: TransactionType.income,
      iconName: 'work',
      colorHex: '#2E7D32',
      sortOrder: 1,
    ),
    CategoryDefault(
      id: 'cat_income_scholarship',
      name: 'Scholarship',
      type: TransactionType.income,
      iconName: 'emoji_events',
      colorHex: '#558B2F',
      sortOrder: 2,
    ),
    CategoryDefault(
      id: 'cat_income_allowance',
      name: 'Allowance',
      type: TransactionType.income,
      iconName: 'account_balance_wallet',
      colorHex: '#689F38',
      sortOrder: 3,
    ),
    CategoryDefault(
      id: 'cat_income_freelance',
      name: 'Freelance',
      type: TransactionType.income,
      iconName: 'laptop',
      colorHex: '#33691E',
      sortOrder: 4,
    ),
    CategoryDefault(
      id: 'cat_income_gifts',
      name: 'Gifts',
      type: TransactionType.income,
      iconName: 'card_giftcard',
      colorHex: '#7CB342',
      sortOrder: 5,
    ),
    CategoryDefault(
      id: 'cat_income_other',
      name: 'Other Income',
      type: TransactionType.income,
      iconName: 'add_circle',
      colorHex: '#8BC34A',
      sortOrder: 6,
    ),

    // ── Expense ──────────────────────────────────────────────────────────────
    CategoryDefault(
      id: 'cat_expense_study_materials',
      name: 'Study Materials',
      type: TransactionType.expense,
      iconName: 'menu_book',
      colorHex: '#E53935',
      sortOrder: 0,
    ),
    CategoryDefault(
      id: 'cat_expense_university_fees',
      name: 'University Fees',
      type: TransactionType.expense,
      iconName: 'account_balance',
      colorHex: '#C62828',
      sortOrder: 1,
    ),
    CategoryDefault(
      id: 'cat_expense_medicines',
      name: 'Medicines',
      type: TransactionType.expense,
      iconName: 'medication',
      colorHex: '#D32F2F',
      sortOrder: 2,
    ),
    CategoryDefault(
      id: 'cat_expense_medical_fees',
      name: 'Medical Fees',
      type: TransactionType.expense,
      iconName: 'local_hospital',
      colorHex: '#B71C1C',
      sortOrder: 3,
    ),
    CategoryDefault(
      id: 'cat_expense_family',
      name: 'Family Expenses',
      type: TransactionType.expense,
      iconName: 'family_restroom',
      colorHex: '#E57373',
      sortOrder: 4,
    ),
    CategoryDefault(
      id: 'cat_expense_money_mom',
      name: 'Money for Mom',
      type: TransactionType.expense,
      iconName: 'favorite',
      colorHex: '#EF5350',
      sortOrder: 5,
    ),
    CategoryDefault(
      id: 'cat_expense_money_dad',
      name: 'Money for Dad',
      type: TransactionType.expense,
      iconName: 'people',
      colorHex: '#F44336',
      sortOrder: 6,
    ),
    CategoryDefault(
      id: 'cat_expense_food',
      name: 'University Food',
      type: TransactionType.expense,
      iconName: 'restaurant',
      colorHex: '#FF5722',
      sortOrder: 7,
    ),
    CategoryDefault(
      id: 'cat_expense_snacks',
      name: 'Snacks',
      type: TransactionType.expense,
      iconName: 'fastfood',
      colorHex: '#FF7043',
      sortOrder: 8,
    ),
    CategoryDefault(
      id: 'cat_expense_transport',
      name: 'Transport Fare',
      type: TransactionType.expense,
      iconName: 'directions_bus',
      colorHex: '#F4511E',
      sortOrder: 9,
    ),
    CategoryDefault(
      id: 'cat_expense_tuition_fare',
      name: 'Tuition Fare',
      type: TransactionType.expense,
      iconName: 'directions_car',
      colorHex: '#BF360C',
      sortOrder: 10,
    ),
    CategoryDefault(
      id: 'cat_expense_personal',
      name: 'Personal Expenses',
      type: TransactionType.expense,
      iconName: 'person',
      colorHex: '#FF8A65',
      sortOrder: 11,
    ),
    CategoryDefault(
      id: 'cat_expense_other',
      name: 'Other Expenses',
      type: TransactionType.expense,
      iconName: 'more_horiz',
      colorHex: '#FFAB91',
      sortOrder: 12,
    ),

    // ── Savings ──────────────────────────────────────────────────────────────
    CategoryDefault(
      id: 'cat_savings_deposit',
      name: 'Savings Deposit',
      type: TransactionType.savings,
      iconName: 'savings',
      colorHex: '#FB8C00',
      sortOrder: 0,
    ),
    CategoryDefault(
      id: 'cat_savings_withdrawal',
      name: 'Savings Withdrawal',
      type: TransactionType.savings,
      iconName: 'money_off',
      colorHex: '#EF6C00',
      sortOrder: 1,
    ),
    CategoryDefault(
      id: 'cat_savings_emergency',
      name: 'Emergency Fund',
      type: TransactionType.savings,
      iconName: 'shield',
      colorHex: '#E65100',
      sortOrder: 2,
    ),
  ];

  static List<CategoryDefault> byType(TransactionType type) =>
      all.where((c) => c.type == type).toList();
}