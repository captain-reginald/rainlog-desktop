#include "installer.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include <QDebug>

namespace {

QString genericData(const QString &relative)
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/.local/share");
    return base + QStringLiteral("/") + relative;
}

QString appsDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
        + QStringLiteral("/Applications");
}

QString installedAppImage()
{
    return appsDir() + QStringLiteral("/RainLog.AppImage");
}

bool copyFile(const QString &from, const QString &to, QString *error)
{
    if (QFileInfo(from).canonicalFilePath() == QFileInfo(to).canonicalFilePath())
        return true;
    if (QFile::exists(to) && !QFile::remove(to)) {
        *error = QStringLiteral("Could not remove %1").arg(to);
        return false;
    }
    if (!QFile::copy(from, to)) {
        *error = QStringLiteral("Could not copy %1 to %2").arg(from, to);
        return false;
    }
    return true;
}

bool writeFile(const QString &path, const QByteArray &contents, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        *error = QStringLiteral("Could not open %1 for writing").arg(path);
        return false;
    }
    if (file.write(contents) != contents.size()) {
        file.close();
        *error = QStringLiteral("Could not write %1").arg(path);
        return false;
    }
    return true;
}

QString quoteExec(const QString &path)
{
    if (!path.contains(QLatin1Char(' ')))
        return path;
    return QStringLiteral("\"%1\"").arg(path);
}

} // namespace

bool runMenuInstall(bool uninstall, QString *error)
{
#ifdef Q_OS_WIN
    *error = QStringLiteral("--install and --uninstall are not supported on Windows");
    return false;
#else
    const QString source = qEnvironmentVariable("APPIMAGE");
    const QString from = source.isEmpty() ? QCoreApplication::applicationFilePath() : source;

    const QString target = installedAppImage();
    const QString desktopFile = genericData(QStringLiteral("applications/rainlog.desktop"));
    const QString iconSvg = genericData(QStringLiteral("icons/hicolor/scalable/apps/rainlog.svg"));
    const QString iconPng = genericData(QStringLiteral("icons/hicolor/256x256/apps/rainlog.png"));

    if (uninstall) {
        QFile::remove(target);
        QFile::remove(desktopFile);
        QFile::remove(iconSvg);
        QFile::remove(iconPng);
        qInfo() << "Uninstalled Rain Log";
        return true;
    }

    if (!QDir().mkpath(appsDir())) {
        *error = QStringLiteral("Could not create %1").arg(appsDir());
        return false;
    }
    if (!copyFile(from, target, error))
        return false;

    const QFileDevice::Permissions exePerms =
        QFileDevice::ReadOwner | QFileDevice::WriteOwner
        | QFileDevice::ExeOwner | QFileDevice::ExeUser
        | QFileDevice::ReadGroup | QFileDevice::ExeGroup
        | QFileDevice::ReadOther | QFileDevice::ExeOther;
    if (!QFile::setPermissions(target, exePerms)) {
        *error = QStringLiteral("Could not set executable permissions on %1").arg(target);
        return false;
    }

    if (!QDir().mkpath(QFileInfo(desktopFile).absolutePath())) {
        *error = QStringLiteral("Could not create %1").arg(QFileInfo(desktopFile).absolutePath());
        return false;
    }
    const QByteArray desktop = QStringLiteral(
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Version=1.0\n"
        "Name=Rain Log\n"
        "Comment=Record daily rainfall and view rolling totals\n"
        "Exec=%1\n"
        "Icon=rainlog\n"
        "Terminal=false\n"
        "Categories=Utility;\n"
        "Keywords=rain;rainfall;weather;gauge;\n"
        "StartupWMClass=rainlog\n"
    ).arg(quoteExec(target)).toUtf8();
    if (!writeFile(desktopFile, desktop, error))
        return false;

    QDir().mkpath(QFileInfo(iconSvg).absolutePath());
    QDir().mkpath(QFileInfo(iconPng).absolutePath());
    if (!copyFile(QStringLiteral(":/icons/rainlog.svg"), iconSvg, error))
        return false;
    if (!copyFile(QStringLiteral(":/icons/rainlog.png"), iconPng, error))
        return false;

    qInfo() << "Installed Rain Log to" << target;
    qInfo() << "Desktop entry written to" << desktopFile;
    return true;
#endif
}
