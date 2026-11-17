#include "themesource.h"

#include <QDir>
#include <QFile>
#include <QFont>
#include <QFontInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

namespace {

QString omarchyStateDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
        + QStringLiteral("/.local/state/omarchy/current/theme");
}

QString omarchyUserShellPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
        + QStringLiteral("/.config/omarchy/shell.toml");
}

} // namespace

ThemeSource::ThemeSource(QObject *parent)
    : QObject(parent)
{
    m_themeDir = omarchyStateDir();

    QFont monospace(QStringLiteral("monospace"));
    monospace.setStyleHint(QFont::Monospace);
    const QString resolved = QFontInfo(monospace).family();
    if (!resolved.isEmpty())
        m_fontFamily = resolved;
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &ThemeSource::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        // A theme switch replaces the whole theme directory; re-read it.
        m_themeDir = omarchyStateDir();

    QFont monospace(QStringLiteral("monospace"));
    monospace.setStyleHint(QFont::Monospace);
    const QString resolved = QFontInfo(monospace).family();
    if (!resolved.isEmpty())
        m_fontFamily = resolved;
        reload();
    });
    reload();
}

QString ThemeSource::readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(file.readAll());
}

void ThemeSource::reload()
{
    const QString colorsPath = m_themeDir + QStringLiteral("/colors.toml");
    const QString shellPath = m_themeDir + QStringLiteral("/shell.toml");
    const QString userShellPath = omarchyUserShellPath();

    m_colorsToml = readFile(colorsPath);
    m_shellToml = readFile(shellPath);
    m_userShellToml = readFile(userShellPath);
    m_omarchyTheme = !m_colorsToml.isEmpty() || !m_shellToml.isEmpty();

    watch();
    // Hyprland's rounding can change with the theme, so refresh it whenever
    // the theme files change.
    queryCornerRadius();
    emit textsChanged();
}

void ThemeSource::watch()
{
    const QStringList watched = m_watcher.files() + m_watcher.directories();
    if (!watched.isEmpty())
        m_watcher.removePaths(watched);

    // Missing files are tolerated: the shared theme layer falls back to its
    // bundled palette when no Omarchy theme is installed.
    const QStringList files = {
        m_themeDir + QStringLiteral("/colors.toml"),
        m_themeDir + QStringLiteral("/shell.toml"),
        omarchyUserShellPath(),
    };
    for (const QString &path : files) {
        if (QFile::exists(path))
            m_watcher.addPath(path);
    }
    if (QDir(m_themeDir).exists())
        m_watcher.addPath(m_themeDir);
}

void ThemeSource::queryCornerRadius()
{
    QProcess process;
    process.start(QStringLiteral("hyprctl"),
                  {QStringLiteral("getoption"), QStringLiteral("decoration:rounding"), QStringLiteral("-j")});
    if (!process.waitForFinished(400)) {
        process.kill();
        return;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0)
        return;

    const QJsonDocument document = QJsonDocument::fromJson(process.readAllStandardOutput());
    if (!document.isObject())
        return;
    const int radius = document.object().value(QStringLiteral("int")).toInt(0);
    if (radius != m_cornerRadius && radius >= 0) {
        m_cornerRadius = radius;
        emit cornerRadiusChanged();
    }
}
