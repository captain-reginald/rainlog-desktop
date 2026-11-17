#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantMap>

// Rainfall store shared with the Omarchy plugin:
//
//   {"entries": {"YYYY-MM-DD": tenths_of_an_inch}}
//
// Writes are atomic (QSaveFile) so a sync client never sees a half-written
// file, and the file plus its directory are watched so both the plugin and a
// sync tool can update the store while this app is open.
class Store : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QString dataPath READ dataPath NOTIFY dataPathChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit Store(QObject *parent = nullptr);

    QVariantMap entries() const { return m_entries; }
    QString dataPath() const { return m_dataPath; }
    bool ready() const { return m_ready; }

    void setDataPath(const QString &path);

    Q_INVOKABLE void setEntry(const QString &key, int tenths);
    Q_INVOKABLE void save();
    Q_INVOKABLE void reload();

signals:
    void entriesChanged();
    void dataPathChanged();
    void readyChanged();

private:
    void watch();
    void scheduleReload();
    void applyDocument(const QByteArray &raw);
    static QString sanitizeKey(const QString &key);

    QVariantMap m_entries;
    QString m_dataPath;
    bool m_ready = false;
    bool m_writing = false;
    bool m_dirty = false;
    QByteArray m_lastWritten;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
