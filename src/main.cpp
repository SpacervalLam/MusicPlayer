#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QDebug>
#include <QQuickStyle>
#include "playlistmodel.h"
#include "playerbackend.h"

int main(int argc, char *argv[])
{
    // 设置 FFmpeg 日志级别为 quiet 以禁用调试输出
    qputenv("AV_LOG_LEVEL", "quiet");
    qputenv("FFREPORT", "file=nul:");
    qputenv("QT_LOGGING_RULES", "*.debug=false;*.info=false");
    
    QGuiApplication app(argc, argv);
    
    // 设置Basic样式以支持控件自定义
    QQuickStyle::setStyle("Basic");

    qmlRegisterType<PlaylistModel>("App", 1, 0, "PlaylistModel");

    PlaylistModel playlist;
    PlayerBackend backend(&playlist);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("playlistModel", &playlist);
    engine.rootContext()->setContextProperty("playerBackend", &backend);

    // load main QML from resource
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}