// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Codebase Flutter';

  @override
  String get login => 'Đăng nhập';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mật khẩu';

  @override
  String get fieldRequired => 'Vui lòng nhập trường này';

  @override
  String get emailInvalid => 'Email không hợp lệ';

  @override
  String passwordTooShort(int min) {
    return 'Mật khẩu phải có ít nhất $min ký tự';
  }

  @override
  String get invalidCredentials => 'Email hoặc mật khẩu không đúng';

  @override
  String demoAccountHint(String email, String password) {
    return 'Tài khoản demo: $email / $password';
  }

  @override
  String welcome(String name) {
    return 'Xin chào, $name!';
  }

  @override
  String get settings => 'Cài đặt';

  @override
  String get darkMode => 'Chế độ tối';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get systemDefault => 'Hệ thống';

  @override
  String get pageNotFound => 'Không tìm thấy trang';

  @override
  String get retry => 'Thử lại';

  @override
  String get errorNetwork => 'Không có kết nối mạng. Vui lòng thử lại.';

  @override
  String get errorTimeout => 'Hết thời gian chờ. Vui lòng thử lại.';

  @override
  String get errorServer => 'Máy chủ đang gặp sự cố.';

  @override
  String get errorUnauthorized =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get offlineBanner => 'Không có kết nối mạng';

  @override
  String get errorUnknown => 'Đã xảy ra lỗi không mong muốn.';
}
