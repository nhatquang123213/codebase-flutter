abstract final class Validators {
  static const int minPasswordLength = 6;

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  static bool isValidPassword(String value) =>
      value.length >= minPasswordLength;
}
