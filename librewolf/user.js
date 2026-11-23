// Linked into every LibreWolf profile by ~/.rice/install.sh. Read at each start,
// so changing one of these in about:config lasts only until the next restart.

// resistFingerprinting makes every site think you're in UTC. Keep the same
// protections through fingerprintingProtection, minus the time zone one and
// canvas ones (canvas randomization garbles image croppers, e.g. avatar uploads).
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.fingerprintingProtection.overrides", "+AllTargets,-JSDateTimeUTC,-CanvasRandomization,-CanvasImageExtractionPrompt,-CanvasExtractionBeforeUserInputIsBlocked,-CanvasExtractionFromThirdPartiesIsBlocked");

// File dialogs through the portal: yazi, where termfilechooser is installed.
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
