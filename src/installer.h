#pragma once

class QString;

// Installs or uninstalls the per-user Rain Log Desktop application menu entry.
bool runMenuInstall(bool uninstall, QString *error);
