/// Shared form validation helpers for Studio forms.
abstract final class StudioValidators {
  static String? required(String? value, {String message = 'This field is required'}) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? email(String? value, {String message = 'Enter a valid email address'}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final pattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!pattern.hasMatch(value.trim())) {
      return message;
    }
    return null;
  }

  static String? minLength(
    String? value,
    int min, {
    String? message,
  }) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length < min) {
      return message ?? 'Enter at least $min characters';
    }
    return null;
  }

  static String? maxLength(
    String? value,
    int max, {
    String? message,
  }) {
    if (value == null) {
      return null;
    }
    if (value.length > max) {
      return message ?? 'Enter at most $max characters';
    }
    return null;
  }

  static String? pattern(
    String? value,
    RegExp regex, {
    required String message,
  }) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!regex.hasMatch(value)) {
      return message;
    }
    return null;
  }
}
