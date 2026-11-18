#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

// User settings for the desktop client. Everything lives in a small JSON file
// under the app config directory so the data store stays purely rainfall:
//
//   ~/.config/rainlog-desktop/config.json     (Linux)
//   %APPDATA%/rainlog-desktop/config.json     (Windows)
//
// The data file itself is the same file the Omarchy plugin uses, which keeps
// the folder sync-friendly across hosts.
class Config : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString dataPath READ dataPath WRITE setDataPath NOTIFY dataPathChanged)
    Q_PROPERTY(int customDays READ customDays WRITE setCustomDays NOTIFY customDaysChanged)
    Q_PROPERTY(int windowWidth READ windowWidth NOTIFY windowGeometryChanged)
    Q_PROPERTY(int windowHeight READ windowHeight NOTIFY windowGeometryChanged)
    Q_PROPERTY(int windowX READ windowX NOTIFY windowGeometryChanged)
    Q_PROPERTY(int windowY READ windowY NOTIFY windowGeometryChanged)

public:
    explicit Config(QObject *parent = nullptr);

    QString dataPath() const { return m_dataPath; }
    void setDataPath(const QString &path);

    int customDays() const { return m_customDays; }
    void setCustomDays(int days);

    int windowWidth() const { return m_windowWidth; }
    int windowHeight() const { return m_windowHeight; }
    int windowX() const { return m_windowX; }
    int windowY() const { return m_windowY; }

    Q_INVOKABLE void setWindowGeometry(int x, int y, int width, int height);

    // Write pending settings now. Called before the window closes because the
    // application may quit before the debounce timer fires.
    Q_INVOKABLE void flush();

signals:
    void dataPathChanged();
    void customDaysChanged();
    void windowGeometryChanged();

private:
    void load();
    void scheduleSave();
    void saveNow();

    static QString configFilePath();
    static QString defaultDataPath();
    // On first run, adopt the path the Omarchy plugin was configured with so
    // both clients read the same file without any migration step.
    static QString pluginDataPath();

    QString m_dataPath;
    int m_customDays = 14;
    int m_windowWidth = 440;
    int m_windowHeight = 0;
    int m_windowX = -1;
    int m_windowY = -1;

    bool m_loaded = false;
    QTimer m_saveTimer;
};
