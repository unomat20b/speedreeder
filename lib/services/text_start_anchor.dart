/// Обрезает [fullText] с первого вхождения [anchorPhrase] (включительно).
/// Возвращает `null`, если фраза не найдена (после trim не пустая).
String? sliceTextFromAnchor(String fullText, String anchorPhrase) {
  final needle = anchorPhrase.trim();
  if (needle.isEmpty) return fullText;
  final i = fullText.indexOf(needle);
  if (i < 0) return null;
  return fullText.substring(i);
}
