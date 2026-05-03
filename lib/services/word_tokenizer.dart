List<String> tokenizeForRsvp(String text) {
  final normalized = text.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  if (normalized.isEmpty) return [];
  return normalized
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList(growable: false);
}
