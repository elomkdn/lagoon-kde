// Rend des éléments d'un thème Plasma avec KSvg, comme Plasma (couleurs du jeu de couleurs
// appliquées), et affiche la couleur obtenue au centre de chaque élément.
// usage : ksvgcolor thème chemin/image élément [élément…]
// ex.  : ksvgcolor Lagoon widgets/background center
#include <KSvg/ImageSet>
#include <KSvg/Svg>
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <cstdio>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc < 4) {
        std::fprintf(stderr, "usage : ksvgcolor thème chemin/image élément [élément…]\n");
        return 1;
    }
    KSvg::ImageSet set;
    set.setBasePath(QStringLiteral("plasma/desktoptheme/"));
    set.setImageSetName(QString::fromLocal8Bit(argv[1]));
    KSvg::Svg svg;
    svg.setImageSet(&set);
    svg.setImagePath(QString::fromLocal8Bit(argv[2]));
    for (int i = 3; i < argc; ++i) {
        QImage img(40, 40, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::transparent);
        QPainter p(&img);
        svg.paint(&p, QRectF(0, 0, 40, 40), QString::fromLocal8Bit(argv[i]));
        p.end();
        const QColor c = img.pixelColor(20, 20);
        std::printf("%-40s %-12s %s alpha %d\n", argv[2], argv[i], qPrintable(c.name()), c.alpha());
    }
    return 0;
}
