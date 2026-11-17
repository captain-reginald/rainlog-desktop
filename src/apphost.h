#pragma once

#include <QObject>
#include <QString>

// Host-side hooks the QML window needs. Kept tiny on purpose: window
// lifecycle work (minimize, close, resize) is plain Qt Quick, so the only
// thing that needs C++ help is activation from a second launch.
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

signals:
    void raiseRequested();

private:
    QString m_startupView;
    bool m_screenshotMode = false;
};
