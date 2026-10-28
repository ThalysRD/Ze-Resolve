class PageWindow {
  static const size = 20;
  List<Map<String, dynamic>> rows = [];
  bool hasMore = false;
  int _generation = 0, _offset = 0;
  late Future<List<Map<String, dynamic>>> Function(int offset, int limit)
  _fetch;

  Future<List<Map<String, dynamic>>> first(
    Future<List<Map<String, dynamic>>> Function(int offset, int limit) fetch,
  ) async {
    final generation = ++_generation;
    _fetch = fetch;
    final page = await fetch(0, size);
    if (generation != _generation) return page;
    rows = [...page];
    _offset = page.length;
    hasMore = page.length == size;
    return rows;
  }

  Future<List<Map<String, dynamic>>> more() async {
    final generation = _generation;
    final page = await _fetch(_offset, size);
    if (generation != _generation) return rows;
    final known = rows.map((row) => row['id']).toSet();
    rows.addAll(page.where((row) => known.add(row['id'])));
    _offset += page.length;
    hasMore = page.length == size;
    return rows;
  }
}
