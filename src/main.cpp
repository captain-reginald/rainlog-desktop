#include "apphost.h"
#include "config.h"
#include "installer.h"
#include "store.h"
#include "themesource.h"

#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDir>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QTimer>

namespace {

// A stable, per-user socket name. Windows pipes have no filesystem path, so
// the name itself has to be unique per account.
QString serverName()
{
    QString user = qEnvironmentVariable("USER");
    if (user.isEmpty())
        user = qEnvironmentVariable("USERNAME", QStringLiteral("user"));
    user.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_.-]")), QStringLiteral("_"));
    return QStringLiteral("rainlog-desktop-") + user;
}

} // namespace

#ifdef Q_OS_WIN
// Load the fonts shipped beside the executable. No system-wide font install is
// needed, and uninstalling the app does not remove fonts the user already had.
QString loadApplicationLocalFont()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList regularCandidates = {
        appDir + QStringLiteral("/JetBrainsMonoNerdFont-Regular.ttf"),
        appDir + QStringLiteral("/fonts/JetBrainsMonoNerdFont-Regular.ttf"),
    };
    const QStringList boldCandidates = {
        appDir + QStringLiteral("/JetBrainsMonoNerdFont-Bold.ttf"),
        appDir + QStringLiteral("/fonts/JetBrainsMonoNerdFont-Bold.ttf"),
    };

    QString family;
    for (const QString &path : regularCandidates) {
        const int id = QFontDatabase::addApplicationFont(path);
        if (id < 0)
            continue;
        const QStringList families = QFontDatabase::applicationFontFamilies(id);
        if (!families.isEmpty()) {
            family = families.first();
            break;
        }
    }
    for (const QString &path : boldCandidates)
        QFontDatabase::addApplicationFont(path);
    return family;
}
#endif

int main(int argc, char *argv[])
{
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("rainlog"));
    app.setApplicationDisplayName(QStringLiteral("Rain Log"));
    app.setApplicationVersion(QStringLiteral(RAINLOG_VERSION));
    app.setDesktopFileName(QStringLiteral("rainlog"));
    app.setQuitOnLastWindowClosed(true);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Record daily rainfall and view rolling totals."));
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption viewOption(
        QStringLiteral("view"),
        QStringLiteral("Start on a particular page: main, settings, or history."),
        QStringLiteral("page"), QStringLiteral("main"));
    const QCommandLineOption screenshotOption(
        QStringLiteral("screenshot"),
        QStringLiteral("Render one frame to a PNG and exit. Pair with "
                       "QT_QPA_PLATFORM=offscreen for documentation shots."),
        QStringLiteral("path"));
    const QCommandLineOption installOption(
        QStringLiteral("install"),
        QStringLiteral("Install Rain Log as a per-user application menu entry and exit."));
    const QCommandLineOption uninstallOption(
        QStringLiteral("uninstall"),
        QStringLiteral("Remove the per-user application menu entry and installed copy, and exit."));
    parser.addOption(installOption);
    parser.addOption(uninstallOption);

    parser.addOption(viewOption);
    parser.addOption(screenshotOption);
    parser.process(app);

    // A second launch should exit immediately instead of opening the GUI.
    if (parser.isSet(installOption) || parser.isSet(uninstallOption)) {
        QString error;
        if (!runMenuInstall(parser.isSet(uninstallOption), &error)) {
            qWarning().noquote() << error;
            return 2;
        }
        return 0;
    }

    // One window per user session. A second launch asks the running instance
    // to come forward and then exits, so double-clicking the launcher never
    // stacks copies of the app.
    const QString socketName = serverName();

    QLocalSocket probe;
    probe.connectToServer(socketName);
    if (probe.waitForConnected(300)) {
        probe.write("raise\n");
        probe.flush();
        probe.waitForBytesWritten(300);
        return 0;
    }

    Config config;
    Store store;
    ThemeSource themeSource;
#ifdef Q_OS_WIN
    const QString appFont = loadApplicationLocalFont();
    if (!appFont.isEmpty())
        themeSource.setFontFamilyOverride(appFont);
#endif
    const QString screenshotPath = parser.value(screenshotOption);
    AppHost host(parser.value(viewOption), !screenshotPath.isEmpty());

    QIcon icon = QIcon::fromTheme(QStringLiteral("rainlog"));
    if (icon.isNull())
        icon = QIcon(QStringLiteral(":/icons/rainlog.ico"));
    app.setWindowIcon(icon);

    QObject::connect(&config, &Config::dataPathChanged, &store,
                     [&store, &config] { store.setDataPath(config.dataPath()); });
    store.setDataPath(config.dataPath());

    QLocalServer server;
    QLocalServer::removeServer(socketName);
    if (server.listen(socketName)) {
        QObject::connect(&server, &QLocalServer::newConnection, &server, [&server, &host] {
            while (QLocalSocket *connection = server.nextPendingConnection()) {
                connection->readAll();
                connection->disconnectFromServer();
                connection->deleteLater();
                host.notifyRaise();
            }
        });
    }

    qmlRegisterSingletonInstance("RainLog", 1, 0, "Config", &config);
    qmlRegisterSingletonInstance("RainLog", 1, 0, "Store", &store);
    qmlRegisterSingletonInstance("RainLog", 1, 0, "ThemeSource", &themeSource);
    qmlRegisterSingletonInstance("RainLog", 1, 0, "Host", &host);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings)
            qWarning().noquote() << warning.toString();
    });
    engine.loadFromModule("RainLog", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;

    // Documentation / regression helper: render one frame and quit. The caller
    // supplies the platform plugin, so this also runs headless.
    if (!screenshotPath.isEmpty()) {
        if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst())) {
            QTimer::singleShot(600, &app, [window, screenshotPath] {
                window->grabWindow().save(screenshotPath);
                QCoreApplication::quit();
            });
        }
    }

    return app.exec();
}
