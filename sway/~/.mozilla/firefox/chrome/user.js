// Enable userChrome.css customizations
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Make sure the userChrome.css file is loaded on startup
user_pref("toolkit.cosmeticAnimations.enabled", false);

// Dark mode settings
user_pref("browser.in-content.dark-mode", true);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("browser.theme.dark-private-windows", true);

// Reduce UI animations for occult theme
user_pref("ui.prefersReducedMotion", 1); 