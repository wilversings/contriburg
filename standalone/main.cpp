#include <QApplication>
#include <QQmlApplicationEngine>
#include <QSurfaceFormat>
#include <QQuickWindow>
#include <QUrl>

int main(int argc, char *argv[])
{
    // Needed for the translucent Window in Main.qml to actually composite
    // over the desktop instead of painting an opaque black background -
    // must be set before the QApplication/QQuickWindow are created.
    QSurfaceFormat format = QSurfaceFormat::defaultFormat();
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    // QGuiApplication is not enough: Qt.labs.platform's SystemTrayIcon pulls
    // in QMenu (QtWidgets) on every backend, not just KDE's - confirmed by
    // testing this app under the generic `qml` runtime, where QGuiApplication
    // aborts with "QWidget: Cannot create a QWidget without QApplication" the
    // moment the tray icon initializes.
    QApplication app(argc, argv);
    app.setOrganizationName("Contriburg");
    app.setApplicationName("Contriburg");
    // The app has no normal top-level window (Main.qml is frameless/Tool,
    // SettingsWindow.qml starts hidden) - without this, Qt would quit the
    // moment the last dialog closes instead of staying resident in the tray.
    app.setQuitOnLastWindowClosed(false);

    // Loaded from disk, not compiled in as a resource: keeps Main.qml free to
    // resolve Scene3D.qml/DataFetcher.js via the same "../contents/ui/..."
    // relative imports it uses when run directly through the `qml` runtime -
    // see CMakeLists.txt, which copies standalone/ and contents/ next to the
    // built executable preserving that layout.
    QQmlApplicationEngine engine;
    engine.load(QUrl::fromLocalFile(app.applicationDirPath() + "/standalone/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
