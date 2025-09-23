class UuidUtils {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isValid(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      return false;
    }
    return _uuidRegex.hasMatch(uuid);
  }
}