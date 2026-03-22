enum FilterLogic { and, or }

enum SortField { date, amount, createdAt }

enum SortOrder { ascending, descending }

class SearchFilter {
  const SearchFilter({
    this.dateFrom,
    this.dateTo,
    this.accountIds,
    this.type,
    this.status,
    this.tagIds,
    this.counterpartyId,
    this.amountMin,
    this.amountMax,
    this.descriptionContains,
  });

  final String? dateFrom;
  final String? dateTo;
  final List<String>? accountIds;
  final String? type;
  final String? status;
  final List<String>? tagIds;
  final String? counterpartyId;
  final int? amountMin;
  final int? amountMax;
  final String? descriptionContains;

  bool get isEmpty =>
      dateFrom == null &&
      dateTo == null &&
      (accountIds == null || accountIds!.isEmpty) &&
      type == null &&
      status == null &&
      (tagIds == null || tagIds!.isEmpty) &&
      counterpartyId == null &&
      amountMin == null &&
      amountMax == null &&
      descriptionContains == null;

  SearchFilter copyWith({
    String? dateFrom,
    String? dateTo,
    List<String>? accountIds,
    String? type,
    String? status,
    List<String>? tagIds,
    String? counterpartyId,
    int? amountMin,
    int? amountMax,
    String? descriptionContains,
  }) {
    return SearchFilter(
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      accountIds: accountIds ?? this.accountIds,
      type: type ?? this.type,
      status: status ?? this.status,
      tagIds: tagIds ?? this.tagIds,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      amountMin: amountMin ?? this.amountMin,
      amountMax: amountMax ?? this.amountMax,
      descriptionContains: descriptionContains ?? this.descriptionContains,
    );
  }
}

class SearchQuery {
  const SearchQuery({
    required this.filter,
    this.filterLogic = FilterLogic.and,
    this.sortField = SortField.date,
    this.sortOrder = SortOrder.descending,
    this.limit = 50,
    this.offset = 0,
  });

  final SearchFilter filter;
  final FilterLogic filterLogic;
  final SortField sortField;
  final SortOrder sortOrder;
  final int limit;
  final int offset;

  SearchQuery copyWith({
    SearchFilter? filter,
    FilterLogic? filterLogic,
    SortField? sortField,
    SortOrder? sortOrder,
    int? limit,
    int? offset,
  }) {
    return SearchQuery(
      filter: filter ?? this.filter,
      filterLogic: filterLogic ?? this.filterLogic,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

class SearchResult<T> {
  const SearchResult({
    required this.items,
    required this.totalCount,
    required this.hasMore,
  });

  final List<T> items;
  final int totalCount;
  final bool hasMore;
}
