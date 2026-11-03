// Enregistre une scène QML image par image, avec une horloge d'animation maîtrisée :
// chaque image avance le temps d'exactement 1/fps seconde, d'où une vidéo sans saccade.
// usage : qmlrecord scène.qml largeur hauteur fps durée_ms dossier_de_sortie [échantillons] [étape:ms]…
// La propriété « stage » de l'élément racine passe à 1 au départ (comme pour un splash),
// puis aux étapes demandées aux instants donnés (ex. 5:4500), comme le fait KSplash.
#include <QAnimationDriver>
#include <QDir>
#include <QGuiApplication>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickGraphicsDevice>
#include <QQuickItem>
#include <QQuickRenderControl>
#include <QQuickRenderTarget>
#include <QQuickWindow>
#include <cmath>
#include <cstdio>

class StepDriver : public QAnimationDriver
{
public:
    qint64 now = 0;
    void setTime(qint64 ms)
    {
        now = ms;
        advance();
    }
    qint64 elapsed() const override { return now; }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc < 7) {
        std::fprintf(stderr, "usage : qmlrecord scène.qml largeur hauteur fps durée_ms dossier\n");
        return 1;
    }
    const QUrl url = QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1]));
    const QSize size(atoi(argv[2]), atoi(argv[3]));
    const int fps = atoi(argv[4]);
    const int duration = atoi(argv[5]);
    const QDir out(QString::fromLocal8Bit(argv[6]));

    StepDriver driver;
    driver.install();

    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    QOpenGLContext context;
    if (!context.create()) {
        std::fprintf(stderr, "impossible de créer un contexte OpenGL\n");
        return 1;
    }
    QOffscreenSurface surface;
    surface.setFormat(context.format());
    surface.create();
    context.makeCurrent(&surface);

    QQuickRenderControl control;
    QQuickWindow window(&control);
    window.setGraphicsDevice(QQuickGraphicsDevice::fromOpenGLContext(&context));
    if (!control.initialize()) {
        std::fprintf(stderr, "échec de l'initialisation du rendu\n");
        return 1;
    }
    QOpenGLFramebufferObject fbo(size, QOpenGLFramebufferObject::CombinedDepthStencil);
    const int samples = argc > 7 ? atoi(argv[7]) : 1; // multi-échantillonnage (anticrénelage)
    window.setRenderTarget(QQuickRenderTarget::fromOpenGLTexture(fbo.texture(), size, samples));
    window.setGeometry(0, 0, size.width(), size.height());
    window.contentItem()->setSize(size);

    QQmlEngine engine;
    QQmlComponent component(&engine, url);
    QObject *object = component.create();
    auto *root = qobject_cast<QQuickItem *>(object);
    if (!root) {
        std::fprintf(stderr, "%s\n", qPrintable(component.errorString()));
        return 1;
    }
    root->setParentItem(window.contentItem());
    root->setSize(size);
    root->setProperty("stage", 1);

    QList<QPair<int, qint64>> stages; // étapes simulées : (étape, instant en ms)
    for (int a = 8; a < argc; ++a) {
        const QStringList parts = QString::fromLocal8Bit(argv[a]).split(QLatin1Char(':'));
        if (parts.size() == 2)
            stages.append({parts[0].toInt(), parts[1].toLongLong()});
    }

    const int frames = int(std::ceil(duration * fps / 1000.0));
    for (int f = 0; f < frames; ++f) {
        const qint64 t = qRound64(f * 1000.0 / fps);
        for (const auto &[stage, at] : std::as_const(stages))
            if (t >= at && root->property("stage").toInt() < stage)
                root->setProperty("stage", stage);
        driver.setTime(t);
        app.processEvents();
        control.polishItems();
        control.beginFrame();
        control.sync();
        control.render();
        control.endFrame();
        context.makeCurrent(&surface); // le rendu de Qt Quick a pu changer le contexte actif
        fbo.toImage().save(out.filePath(QString::asprintf("%05d.png", f)));
    }
    std::printf("%d images\n", frames);
    return 0;
}
