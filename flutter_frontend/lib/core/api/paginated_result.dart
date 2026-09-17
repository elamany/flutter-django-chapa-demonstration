/// Generic wrapper for DRF paginated responses.
///
/// Shape from the API:
///   {
///     "count": 42,
///     "next": "http://.../campaigns/?page=2",
///     "previous": null,
///     "results": [ ... ]
///   }
///
/// Every list endpoint in the app (campaigns, donations, etc.) uses
/// this same shape, so one wrapper covers them all.
class PaginatedResult<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  const PaginatedResult({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawResults = json['results'];
    final items = <T>[];

    if (rawResults is List) {
      for (final entry in rawResults) {
        if (entry is Map<String, dynamic>) {
          items.add(itemParser(entry));
        } else if (entry is Map) {
          items.add(itemParser(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return PaginatedResult(
      count: (json['count'] ?? 0) as int,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: items,
    );
  }

  bool get hasNext => next != null && next!.isNotEmpty;
  bool get hasPrevious => previous != null && previous!.isNotEmpty;
  bool get isEmpty => results.isEmpty;
}