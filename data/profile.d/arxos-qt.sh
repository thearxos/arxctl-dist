# ArxOS: Qt apps (Konsole, the installer, Qt tools) follow the desktop's GTK look: its colours,
# fonts and icons, through Qt's own GTK 3 platform theme. No extra packages. A user's own choice
# (qt6ct, Kvantum) set in the environment or ~/.xprofile wins over this default.
[ -n "${QT_QPA_PLATFORMTHEME:-}" ] || export QT_QPA_PLATFORMTHEME=gtk3
