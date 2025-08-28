class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final int? nextPage;
  final int? prevPage;

  const PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    this.nextPage,
    this.prevPage,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? false,
      nextPage: json['nextPage'],
      prevPage: json['prevPage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
      'hasNextPage': hasNextPage,
      'hasPrevPage': hasPrevPage,
      'nextPage': nextPage,
      'prevPage': prevPage,
    };
  }
}

class PaginatedResponse<T> {
  final List<T> data;
  final PaginationModel pagination;

  const PaginatedResponse({
    required this.data,
    required this.pagination,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    final items = dataList.map((item) => itemFromJson(item as Map<String, dynamic>)).toList();
    
    return PaginatedResponse<T>(
      data: items,
      pagination: PaginationModel.fromJson(json['pagination'] ?? {}),
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) itemToJson) {
    return {
      'data': data.map((item) => itemToJson(item)).toList(),
      'pagination': pagination.toJson(),
    };
  }
}