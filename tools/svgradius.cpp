// Mesure le rayon des coins d'éléments SVG, rendus avec QtSvg comme dans Plasma.
// usage : svgradius fichier.svg[z] id [id…]
// Pour chaque id : taille de l'élément et rayon ajusté (px) des coins HG, HD, BG, BD.
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QSvgRenderer>
#include <cmath>
#include <cstdio>

static const int S = 8; // sur-échantillonnage

// Retrait (px) du bord de la forme, ligne par ligne depuis un coin.
static double fitRadius(const QImage &img, QRect box, bool right, bool bottom, int thr)
{
    QVector<double> inset;
    const int rows = std::min(box.height(), 60 * S);
    for (int i = 0; i < rows; ++i) {
        const int y = bottom ? box.bottom() - i : box.top() + i;
        int k = 0;
        for (; k < box.width(); ++k) {
            const int x = right ? box.right() - k : box.left() + k;
            if (qAlpha(img.pixel(x, y)) > thr)
                break;
        }
        inset << double(k) / S;
    }
    double best = 0, bestErr = 1e18;
    for (double r = 0; r <= 60; r += 0.25) {
        double err = 0;
        for (int i = 0; i < inset.size(); ++i) {
            const double d = (i + 0.5) / S;
            const double expect = d < r ? r - std::sqrt(std::max(0.0, r * r - (r - d) * (r - d))) : 0;
            err += (inset[i] - expect) * (inset[i] - expect);
        }
        if (err < bestErr) {
            bestErr = err;
            best = r;
        }
    }
    return best;
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc < 3) {
        std::fprintf(stderr, "usage : svgradius fichier.svg id [id…]\n");
        return 1;
    }
    QSvgRenderer svg(QString::fromLocal8Bit(argv[1]));
    if (!svg.isValid()) {
        std::fprintf(stderr, "SVG invalide : %s\n", argv[1]);
        return 1;
    }
    // --bounds : affiche seulement la taille des éléments (unités du SVG)
    const bool boundsOnly = QByteArray(argv[2]) == "--bounds";
    for (int a = boundsOnly ? 3 : 2; a < argc; ++a) {
        const QString id = QString::fromLocal8Bit(argv[a]);
        if (boundsOnly) {
            const QRectF b = svg.elementExists(id) ? svg.transformForElement(id).mapRect(svg.boundsOnElement(id)) : QRectF();
            std::printf("%-28s %s\n", argv[a], svg.elementExists(id) ? qPrintable(QString::asprintf("%.2fx%.2f", b.width(), b.height())) : "absent");
            continue;
        }
        if (!svg.elementExists(id)) {
            std::printf("%-28s absent\n", argv[a]);
            continue;
        }
        const QRectF b = svg.transformForElement(id).mapRect(svg.boundsOnElement(id));
        QImage img(std::ceil(b.width() * S) + 2, std::ceil(b.height() * S) + 2, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::transparent);
        QPainter p(&img);
        svg.render(&p, id, QRectF(1, 1, b.width() * S, b.height() * S));
        p.end();
        // seuil à mi-opacité de l'élément : les états « repos » sont souvent très transparents
        int maxA = 0;
        for (int y = 0; y < img.height(); ++y)
            for (int x = 0; x < img.width(); ++x)
                maxA = std::max(maxA, qAlpha(img.pixel(x, y)));
        const int thr = maxA / 2;
        QRect box;
        for (int y = 0; y < img.height(); ++y)
            for (int x = 0; x < img.width(); ++x)
                if (maxA > 0 && qAlpha(img.pixel(x, y)) > thr)
                    box |= QRect(x, y, 1, 1);
        if (box.isEmpty()) {
            std::printf("%-28s %5.1fx%-5.1f vide\n", argv[a], b.width(), b.height());
            continue;
        }
        std::printf("%-28s %5.1fx%-5.1f  HG %5.2f  HD %5.2f  BG %5.2f  BD %5.2f  (opacité max %d%%)\n", argv[a],
                    box.width() / double(S), box.height() / double(S),
                    fitRadius(img, box, false, false, thr), fitRadius(img, box, true, false, thr),
                    fitRadius(img, box, false, true, thr), fitRadius(img, box, true, true, thr), maxA * 100 / 255);
    }
    return 0;
}
