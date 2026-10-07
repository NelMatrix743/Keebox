import 'package:keebox/config/environment_config.dart';

abstract final class APIEndpoints {
  static final String baseUrl = EnvironmentConfig.apiBaseUrl;
  static final String authBaseUrl = '$baseUrl/auth';

  static final String register = '$authBaseUrl/register';
  static final String registerVerifyOtp = '$register/verify-otp';
  static final String registerResendOtp = '$register/resend-otp';
  static final String registerCreatePin = '$register/create-pin';

  static final String login = '$authBaseUrl/login';
  static final String loginVerifyPin = '$login/verify-pin';
  static final String logout = '$authBaseUrl/logout';

  static final String resetBaseUrl = '$authBaseUrl/reset';
  static final String resetPassword = '$resetBaseUrl/password';
  static final String resetPin = '$resetBaseUrl/pin';
  static final String resetResendOtp = '$resetBaseUrl/resend-otp';
  static final String resetVerifyOtp = '$resetBaseUrl/verify-otp';
  static final String resetPasswordComplete = '$resetPassword/complete';
  static final String resetPinComplete = '$resetPin/complete';
}
