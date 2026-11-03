// Assemble un cadre Plasma (FrameSvg) à partir de ses 9 pièces, rendues avec QtSvg,
// avec son ombre, pour prévisualiser un thème.
// usage : svgframe fichier.svg[z] préfixe largeur hauteur échelle fond(#rrggbb) sortie.png
// préfixe : "" pour les pièces sans préfixe (topleft…), sinon "normal", "focus"…
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QSvgRenderer>
#include <cstdio>

static QSvgRenderer *svg;

static QString el(const QString &prefix, const QString &name)
{
    return prefix.isEmpty() ? name : prefix + QLatin1Char('-') + name;
}

static QSizeF size(const QString &id)
{
    if (!svg->elementExists(id))
        return {};
    return svg->transformForElement(id).mapRect(svg->boundsOnElement(id)).size();
}

static qreal hint(const QString &id, bool horizontal)
{
    const QSizeF s = size(id);
    return horizontal ? s.width() : s.height();
}

// Dessine un cadre en 9 pièces dans le rectangle r.
static void drawFrame(QPainter &p, const QString &prefix, QRectF r)
{
    const qreal l = size(el(prefix, "left")).width(), t = size(el(prefix, "top")).height();
    const qreal rr = size(el(prefix, "right")).width(), b = size(el(prefix, "bottom")).height();
    auto put = [&](const char *name, QRectF dst) {
        const QString id = el(prefix, name);
        if (svg->elementExists(id) && dst.width() > 0 && dst.height() > 0)
            svg->render(&p, id, dst);
    };
    put("topleft", {r.left(), r.top(), l, t});
    put("top", {r.left() + l, r.top(), r.width() - l - rr, t});
    put("topright", {r.right() - rr, r.top(), rr, t});
    put("left", {r.left(), r.top() + t, l, r.height() - t - b});
    put("center", {r.left() + l, r.top() + t, r.width() - l - rr, r.height() - t - b});
    put("right", {r.right() - rr, r.top() + t, rr, r.height() - t - b});
    put("bottomleft", {r.left(), r.bottom() - b, l, b});
    put("bottom", {r.left() + l, r.bottom() - b, r.width() - l - rr, b});
    put("bottomright", {r.right() - rr, r.bottom() - b, rr, b});
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc < 8) {
        std::fprintf(stderr, "usage : svgframe fichier préfixe largeur hauteur échelle fond sortie.png\n");
        return 1;
    }
    QSvgRenderer renderer(QString::fromLocal8Bit(argv[1]));
    svg = &renderer;
    const QString prefix = QString::fromLocal8Bit(argv[2]);
    const qreal w = atof(argv[3]), h = atof(argv[4]), scale = atof(argv[5]);
    const int pad = 40;

    QImage img((w + 2 * pad) * scale, (h + 2 * pad) * scale, QImage::Format_ARGB32_Premultiplied);
    img.fill(QColor(QString::fromLocal8Bit(argv[6])));
    QPainter p(&img);
    p.scale(scale, scale);
    const QRectF frame(pad, pad, w, h);

    // ombre : pièces shadow-* autour du cadre
    if (prefix.isEmpty() && svg->elementExists("shadow-topleft")) {
        // KWin élargit la fenêtre des marges shadow-hint-* ; les tuiles débordent dessous
        const qreal sl = hint("shadow-hint-left-margin", true), st = hint("shadow-hint-top-margin", false);
        const qreal sr = hint("shadow-hint-right-margin", true), sb = hint("shadow-hint-bottom-margin", false);
        drawFrame(p, "shadow", frame.adjusted(-sl, -st, sr, sb));
    }
    drawFrame(p, prefix, frame);
    p.end();
    img.save(QString::fromLocal8Bit(argv[7]));
    return 0;
}
