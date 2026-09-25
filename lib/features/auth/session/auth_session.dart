class AppSession {
  static bool isLoggedIn = false;
  static String selectedProfile = 'cliente';

  static void login(String profile) {
    isLoggedIn = true;
    selectedProfile = profile;
  }

  static void logout() {
    isLoggedIn = false;
    selectedProfile = 'cliente';
  }
}
