#pragma once

class QString;

// Installs or uninstalls the per-user Rain Log application menu entry.
bool runMenuInstall(bool uninstall, QString *error);
