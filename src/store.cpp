#include "store.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>

namespace {

// The plugin stores rainfall with JSON.stringify(value, null, 2): two-space
// indentation, one entry per line, no trailing newline. Writing the same bytes
// keeps the synced file stable when both clients edit it.
QByteArray serializeEntries(const QVariantMap &entries)
{
    if (entries.isEmpty())
        return QByteArray("{\n  \"entries\": {}\n}");

    QByteArray out = "{\n  \"entries\": {\n";
    bool first = true;
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        if (!first)
            out += ",\n";
        first = false;
        out += "    \"" + it.key().toUtf8() + "\": " + QByteArray::number(it.value().toInt());
    }
    out += "\n  }\n}";
    return out;
}

} // namespace

Store::Store(QObject *parent)
    : QObject(parent)
{
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(150);
    connect(&m_reloadTimer, &QTimer::timeout, this, &Store::reload);

    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &Store::scheduleReload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Store::scheduleReload);
}

QString Store::sanitizeKey(const QString &key)
{
    static const QRegularExpression pattern(QStringLiteral("^\\d{4}-\\d{2}-\\d{2}$"));
    return pattern.match(key).hasMatch() ? key : QString();
}

void Store::setDataPath(const QString &path)
{
    if (path == m_dataPath)
        return;

    m_dataPath = path;
    m_ready = false;
    emit dataPathChanged();
    emit readyChanged();

    // The folder is created on demand: a fresh install should not need the
    // user to make ~/Documents/rainlog by hand, and a synced folder is left
    // exactly as the sync client laid it out.
    const QFileInfo info(m_dataPath);
    QDir().mkpath(info.absolutePath());

    m_entries.clear();
    emit entriesChanged();

    watch();
    reload();
}

void Store::watch()
{
    const QStringList watched = m_watcher.files() + m_watcher.directories();
    if (!watched.isEmpty())
        m_watcher.removePaths(watched);

    if (m_dataPath.isEmpty())
        return;

    const QFileInfo info(m_dataPath);
    if (info.exists())
        m_watcher.addPath(m_dataPath);
    // Watch the directory too: sync tools and editors often replace the file
    // rather than writing in place, which drops the file watch.
    if (info.absoluteDir().exists())
        m_watcher.addPath(info.absolutePath());
}

void Store::scheduleReload()
{
    if (m_writing)
        return;
    m_reloadTimer.start();
}

void Store::reload()
{
    if (m_dataPath.isEmpty())
        return;

    QFile file(m_dataPath);
    if (!file.exists()) {
        // First run: create an empty store so the folder is immediately a
        // valid sync unit.
        m_lastWritten.clear();
        m_dirty = true;
        save();
        if (!m_ready) {
            m_ready = true;
            emit readyChanged();
        }
        return;
    }

    if (!file.open(QIODevice::ReadOnly)) {
        // The scanner may have it open for a moment; retry once shortly.
        m_reloadTimer.start();
        return;
    }

    const QByteArray raw = file.readAll();
    file.close();

    if (raw == m_lastWritten) {
        if (!m_ready) {
            m_ready = true;
            emit readyChanged();
        }
        // Re-arm the watch if a replace dropped it.
        watch();
        return;
    }

    applyDocument(raw);
    // Remember the bytes we loaded so our own save is a no-op until the user
    // actually changes something, and so watch events from our own write do
    // not re-parse the file.
    m_lastWritten = raw;
    watch();
}

void Store::applyDocument(const QByteArray &raw)
{
    QVariantMap next;
    QJsonParseError error{};
    const QJsonDocument document = QJsonDocument::fromJson(raw, &error);
    if (error.error == QJsonParseError::NoError && document.isObject()) {
        const QJsonObject entries = document.object().value(QStringLiteral("entries")).toObject();
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            if (!sanitizeKey(it.key()).isEmpty())
                next.insert(it.key(), it.value().toInt());
        }
    }

    m_entries = next;
    m_dirty = false;
    m_ready = true;
    emit entriesChanged();
    emit readyChanged();
}

void Store::setEntry(const QString &key, int tenths)
{
    const QString clean = sanitizeKey(key);
    if (clean.isEmpty())
        return;

    QVariantMap next = m_entries;
    if (tenths <= 0)
        next.remove(clean);
    else
        next.insert(clean, tenths);

    if (next == m_entries)
        return;

    m_entries = next;
    emit entriesChanged();
    m_dirty = true;
    save();
}

void Store::save()
{
    if (m_dataPath.isEmpty() || !m_dirty)
        return;

    const QByteArray payload = serializeEntries(m_entries);

    if (payload == m_lastWritten) {
        m_dirty = false;
        return;
    }

    const QFileInfo info(m_dataPath);
    QDir().mkpath(info.absolutePath());

    m_writing = true;
    QSaveFile file(m_dataPath);
    bool ok = file.open(QIODevice::WriteOnly);
    if (ok) {
        file.write(payload);
        ok = file.commit();
    }
    m_writing = false;

    if (ok) {
        m_lastWritten = payload;
        m_dirty = false;
    }

    if (!m_ready) {
        m_ready = true;
        emit readyChanged();
    }
    watch();
}
