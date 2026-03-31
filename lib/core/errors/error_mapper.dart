import 'app_exception.dart';

String loginMessageFor(AppException e) {
  final message = e.message.toLowerCase();

  if (message.contains('esiid')) {
    return 'The ESIID looks invalid. Please verify the 17-digit ESIID and try again.';
  }

  if (message.contains('username') ||
      message.contains('password') ||
      message.contains('credential') ||
      message.contains('authenticate') ||
      message.contains('invalid login') ||
      message.contains('invalid or expired') ||
      message.contains('unauthorized') ||
      message.contains('incorrect username or password') ||
      message.contains('status code 401') ||
      message.contains(' 401')) {
    return 'Incorrect username or password. Please try again.';
  }

  switch (e.code) {
    case 'SMT_VALIDATION_ERROR':
      return 'Please check your login details and ESIID, then try again.';
    case 'SMT_SESSION_EXPIRED':
      // Backend may currently return this for invalid login auth responses as well.
      return 'Incorrect username or password. Please try again.';
    case 'SMT_RATE_LIMIT':
      return 'Too many login attempts. Please wait a moment and try again.';
    case 'AUTH_INVALID_CREDENTIALS':
      return 'Incorrect username or password. Please try again.';
    case 'AUTH_ERROR':
      if (message.contains('internal server error') ||
          message.contains('status code 500') ||
          message.contains(' 500')) {
        return 'Unable to sign in right now. Please try again in a moment.';
      }
      return 'Unable to sign in right now. Please check your network and try again.';
    case 'API_KEY_UNAUTHORIZED':
      return 'Unable to sign in right now. Please try again in a moment.';
    default:
      return 'Unable to log in right now. Please try again.';
  }
}

String userMessageFor(AppException e) {
  switch (e.code) {
    case 'SMT_VALIDATION_ERROR':
      return 'Please check your input and try again.';
    case 'SMT_SESSION_EXPIRED':
      return 'Session expired. Please log in again.';
    case 'SMT_RATE_LIMIT':
      return 'Too many requests. Please wait and try again.';
    case 'API_KEY_UNAUTHORIZED':
      return 'Client is not authorized. Check API key config.';
    default:
      return e.message.isNotEmpty ? e.message : 'Something went wrong.';
  }
}
