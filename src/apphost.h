#pragma once

#include <QObject>
#include <QProcess>
#include <QStandardPaths>
#include <QString>
#include <QtGlobal>

// Host-side hooks the QML window needs. Window lifecycle work (minimize,
// close, ordinary resize) is plain Qt Quick; the C++ help is activation from
// a second launch and Hyprland's mapped-window resize request.
class AppHost : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString startupView READ startupView CONSTANT)
    Q_PROPERTY(bool screenshotMode READ screenshotMode CONSTANT)

public:
    AppHost(const QString &startupView, bool screenshotMode, QObject *parent = nullptr)
        : QObject(parent)
        , m_startupView(startupView)
        , m_screenshotMode(screenshotMode)
    {
    }

    // "main", "settings", or "history", from --view.
    QString startupView() const { return m_startupView; }

    // When true the host ignores the saved window size so each page is
    // rendered at the height its content asks for.
    bool screenshotMode() const { return m_screenshotMode; }

    // Called by the single-instance IPC server in main.cpp.
    void notifyRaise() { emit raiseRequested(); }

    // A mapped Wayland toplevel cannot reliably resize itself by changing its
    // QML height. Ask Hyprland for the exact size instead; other platforms
    // and compositors simply return false so Qt can handle the request.
    Q_INVOKABLE bool requestWindowResize(int width, int height) const
    {
        if (m_screenshotMode)
            return false;
        if (width <= 0 || height <= 0)
            return false;
        if (qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE"))
            return false;
        if (QStandardPaths::findExecutable(QStringLiteral("hyprctl")).isEmpty())
            return false;

        const QString command = QStringLiteral(
            "hl.dsp.window.resize({ x = %1, y = %2, relative = false, window = \"class:rainlog-desktop\" })")
            .arg(width)
            .arg(height);
        return QProcess::startDetached(QStringLiteral("hyprctl"),
                                       {QStringLiteral("--quiet"), QStringLiteral("dispatch"), command});
    }

signals:
    void raiseRequested();

private:
    QString m_startupView;
    bool m_screenshotMode = false;
};
