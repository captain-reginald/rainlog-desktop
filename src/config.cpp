#include "config.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>

namespace {

constexpr int kDefaultCustomDays = 14;
constexpr int kDefaultWindowWidth = 440;
constexpr int kDefaultWindowHeight = 0;

QString pluginDataPathIn(const QJsonValue &value)
{
    if (value.isObject()) {
        const QJsonObject object = value.toObject();
        if (object.value(QStringLiteral("id")).toString()
                == QStringLiteral("io.github.captain-reginald.rainlog")
            && object.value(QStringLiteral("dataPath")).isString()) {
            return object.value(QStringLiteral("dataPath")).toString();
        }
        for (auto it = object.begin(); it != object.end(); ++it) {
            const QString found = pluginDataPathIn(it.value());
            if (!found.isEmpty())
                return found;
        }
    } else if (value.isArray()) {
        const QJsonArray array = value.toArray();
        for (const QJsonValue &entry : array) {
            const QString found = pluginDataPathIn(entry);
            if (!found.isEmpty())
                return found;
        }
    }
    return {};
}

} // namespace

Config::Config(QObject *parent)
    : QObject(parent)
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(250);
    connect(&m_saveTimer, &QTimer::timeout, this, &Config::saveNow);
    load();
}

QString Config::configFilePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    return dir + QStringLiteral("/config.json");
}

QString Config::defaultDataPath()
{
    QString docs = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (docs.isEmpty())
        docs = QDir::homePath();
    return docs + QStringLiteral("/rainlog/rainlog.json");
}

QString Config::pluginDataPath()
{
    const QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    const QString shellJson = home + QStringLiteral("/.config/omarchy/shell.json");
    QFile file(shellJson);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    if (!document.isObject())
        return {};
    return pluginDataPathIn(document.object());
}

void Config::load()
{
    const QString path = configFilePath();
    QFile file(path);
    bool hasFile = file.open(QIODevice::ReadOnly);
    if (hasFile) {
        const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
        if (document.isObject()) {
            const QJsonObject object = document.object();
            m_dataPath = object.value(QStringLiteral("dataPath")).toString();
            m_customDays = object.value(QStringLiteral("customDays")).toInt(kDefaultCustomDays);
            m_windowWidth = object.value(QStringLiteral("windowWidth")).toInt(kDefaultWindowWidth);
            m_windowHeight = object.value(QStringLiteral("windowHeight")).toInt(kDefaultWindowHeight);
            m_windowX = object.value(QStringLiteral("windowX")).toInt(-1);
            m_windowY = object.value(QStringLiteral("windowY")).toInt(-1);
        }
    }

    if (m_dataPath.isEmpty()) {
        const QString pluginPath = pluginDataPath();
        m_dataPath = pluginPath.isEmpty() ? defaultDataPath() : pluginPath;
    }
    if (m_customDays < 1)
        m_customDays = kDefaultCustomDays;
    if (m_windowWidth < 200)
        m_windowWidth = kDefaultWindowWidth;
    if (m_windowHeight != 0 && m_windowHeight < 120)
        m_windowHeight = kDefaultWindowHeight;

    m_loaded = true;

    if (!hasFile)
        scheduleSave();
}

void Config::setDataPath(const QString &path)
{
    const QString trimmed = path.trimmed();
    if (trimmed.isEmpty() || trimmed == m_dataPath)
        return;
    m_dataPath = trimmed;
    emit dataPathChanged();
    scheduleSave();
}

void Config::setCustomDays(int days)
{
    if (days < 1)
        days = kDefaultCustomDays;
    if (days == m_customDays)
        return;
    m_customDays = days;
    emit customDaysChanged();
    scheduleSave();
}

void Config::setWindowGeometry(int x, int y, int width, int height)
{
    if (width < 200)
        width = kDefaultWindowWidth;
    if (height != 0 && height < 120)
        height = kDefaultWindowHeight;

    if (x == m_windowX && y == m_windowY && width == m_windowWidth && height == m_windowHeight)
        return;

    m_windowX = x;
    m_windowY = y;
    m_windowWidth = width;
    m_windowHeight = height;
    emit windowGeometryChanged();
    scheduleSave();
}

void Config::scheduleSave()
{
    if (!m_loaded)
        return;
    m_saveTimer.start();
}

void Config::flush()
{
    m_saveTimer.stop();
    saveNow();
}

void Config::saveNow()
{
    const QString path = configFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());

    QJsonObject object;
    object.insert(QStringLiteral("dataPath"), m_dataPath);
    object.insert(QStringLiteral("customDays"), m_customDays);
    object.insert(QStringLiteral("windowWidth"), m_windowWidth);
    object.insert(QStringLiteral("windowHeight"), m_windowHeight);
    object.insert(QStringLiteral("windowX"), m_windowX);
    object.insert(QStringLiteral("windowY"), m_windowY);

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    file.commit();
}
