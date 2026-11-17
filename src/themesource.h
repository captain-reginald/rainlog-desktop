#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>

// Supplies the raw Omarchy theme files to the shared QML layer. The parsing
// and derived tokens live in QML (Theme.qml) so the plugin and the desktop
// client share one implementation; this class only reads files, watches them,
// and asks Hyprland for its corner radius.
class ThemeSource : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString colorsToml READ colorsToml NOTIFY textsChanged)
    Q_PROPERTY(QString shellToml READ shellToml NOTIFY textsChanged)
    Q_PROPERTY(QString userShellToml READ userShellToml NOTIFY textsChanged)
    Q_PROPERTY(int cornerRadius READ cornerRadius NOTIFY cornerRadiusChanged)
    Q_PROPERTY(QString fontFamily READ fontFamily CONSTANT)
    Q_PROPERTY(bool omarchyTheme READ omarchyTheme NOTIFY textsChanged)

public:
    explicit ThemeSource(QObject *parent = nullptr);

    QString colorsToml() const { return m_colorsToml; }
    QString shellToml() const { return m_shellToml; }
    QString userShellToml() const { return m_userShellToml; }
    int cornerRadius() const { return m_cornerRadius; }
    // The concrete family resolves "monospace" on fontconfig systems, so glyphs
    // such as the gear and arrows come from the same font the shell uses. On
    // Windows the host installs an application-local family instead.
    QString fontFamily() const { return m_fontFamily; }
    bool omarchyTheme() const { return m_omarchyTheme; }

    // Called before the QML engine loads a host-provided application font.
    void setFontFamilyOverride(const QString &family)
    {
        if (!family.isEmpty())
            m_fontFamily = family;
    }

    Q_INVOKABLE void reload();

signals:
    void textsChanged();
    void cornerRadiusChanged();

private:
    static QString readFile(const QString &path);
    void watch();
    void queryCornerRadius();

    QString m_colorsToml;
    QString m_shellToml;
    QString m_userShellToml;
    bool m_omarchyTheme = false;
    int m_cornerRadius = 0;
    QString m_fontFamily = QStringLiteral("monospace");
    QFileSystemWatcher m_watcher;
    QString m_themeDir;
};
