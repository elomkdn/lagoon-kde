// Tous les états des contrôles Qt d'un thème Kvantum dans une seule image, rendue hors écran :
// une ligne par contrôle ; repos, survol, appui, focus, fenêtre inactive, désactivé. Les états
// sont forcés dans les options du style, avec animate_states à false pour voir leur état final ;
// pour le survol, le curseur est posé sur le widget : Kvantum vérifie qu'il y est vraiment.
// usage : kvstates <dossier contenant le thème Kvantum> <nom du thème> <sortie.png>
// ex.  : kvstates ~/.local/share/themes/Lagoon/Kvantum Lagoon etats.png
#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QCursor>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QLineEdit>
#include <QListView>
#include <QMenu>
#include <QPainter>
#include <QProgressBar>
#include <QPushButton>
#include <QRadioButton>
#include <QScrollBar>
#include <QSlider>
#include <QStyleOption>
#include <QTabBar>
#include <QTemporaryDir>
#include <QToolBar>
#include <QToolButton>
#include <QVBoxLayout>
#include <cstdio>
#include <functional>

// QWidget::activateWindow ne fait rien hors écran ; setActiveWindow, obsolète, le fait encore
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

using S = QStyle::State;

static void settle(int ms)
{
    QElapsedTimer t;
    t.start();
    while (t.elapsed() < ms)
        QApplication::processEvents();
}

struct Column {
    const char *name;
    S state;
    bool inactive = false;
};

int main(int argc, char **argv)
{
    if (argc < 4) {
        std::fprintf(stderr, "usage : kvstates <dossier du thème> <nom> <sortie.png>\n");
        return 1;
    }
    // Kvantum lit son thème dans $XDG_CONFIG_HOME/Kvantum : une copie, sans les animations
    QTemporaryDir cfg;
    const QString name = QString::fromLocal8Bit(argv[2]);
    const QString dest = cfg.path() + QStringLiteral("/Kvantum/") + name;
    QDir().mkpath(dest);
    const QDir src(QString::fromLocal8Bit(argv[1]));
    if (!QFile::copy(src.filePath(name + QStringLiteral(".svg")), dest + QLatin1Char('/') + name + QStringLiteral(".svg"))) {
        std::fprintf(stderr, "thème introuvable : %s\n", argv[1]);
        return 1;
    }
    QFile in(src.filePath(name + QStringLiteral(".kvconfig")));
    QFile out(dest + QLatin1Char('/') + name + QStringLiteral(".kvconfig"));
    if (!in.open(QIODevice::ReadOnly) || !out.open(QIODevice::WriteOnly))
        return 1;
    out.write(in.readAll().replace("animate_states=true", "animate_states=false"));
    out.close();
    QFile kv(cfg.path() + QStringLiteral("/Kvantum/kvantum.kvconfig"));
    if (!kv.open(QIODevice::WriteOnly))
        return 1;
    kv.write("[General]\ntheme=" + QByteArray(argv[2]) + "\n");
    kv.close();
    qputenv("XDG_CONFIG_HOME", cfg.path().toLocal8Bit());
    qputenv("QT_STYLE_OVERRIDE", "kvantum");
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QApplication app(argc, argv);

    // de vrais widgets, montrés : Kvantum regarde leur type et leur parent
    QWidget win;
    auto *lay = new QVBoxLayout(&win);
    auto *toolbar = new QToolBar;
    auto *tool = new QToolButton;
    tool->setText(QStringLiteral("Outil"));
    tool->setAutoRaise(true);
    toolbar->addWidget(tool);
    auto *plainTool = new QToolButton;
    plainTool->setText(QStringLiteral("Outil"));
    auto *push = new QPushButton(QStringLiteral("Bouton"));
    auto *defaultPush = new QPushButton(QStringLiteral("Bouton"));
    defaultPush->setDefault(true);
    auto *combo = new QComboBox;
    combo->addItem(QStringLiteral("Liste"));
    auto *edit = new QLineEdit(QStringLiteral("Texte"));
    auto *check = new QCheckBox(QStringLiteral("Case"));
    auto *radio = new QRadioButton(QStringLiteral("Choix"));
    auto *tabs = new QTabBar;
    tabs->addTab(QStringLiteral("Onglet"));
    auto *menu = new QMenu;
    auto *list = new QListView;
    auto *slider = new QSlider(Qt::Horizontal);
    slider->setValue(55);
    auto *scroll = new QScrollBar(Qt::Horizontal);
    auto *progress = new QProgressBar;
    progress->setValue(55);
    for (QWidget *w : {static_cast<QWidget *>(toolbar), static_cast<QWidget *>(plainTool), static_cast<QWidget *>(push), static_cast<QWidget *>(defaultPush), static_cast<QWidget *>(combo),
                       static_cast<QWidget *>(edit), static_cast<QWidget *>(check), static_cast<QWidget *>(radio), static_cast<QWidget *>(tabs),
                       static_cast<QWidget *>(list), static_cast<QWidget *>(slider), static_cast<QWidget *>(scroll), static_cast<QWidget *>(progress)})
        lay->addWidget(w);
    win.resize(400, 600);
    win.show();
    menu->addAction(QStringLiteral("Élément"));
    menu->show();
    QApplication::setActiveWindow(&win);
    settle(200);
    QWidget other;  // prend le focus pour la colonne « fenêtre inactive »
    other.resize(50, 50);

    const int cellW = 130, cellH = 46, labelW = 150, headH = 26;
    QStyle *st = app.style();

    using Draw = std::function<void(QPainter &, QRect, S)>;
    const auto withPalette = [](QStyleOption &o, QWidget *w, QRect r, S s) {
        o.initFrom(w);
        o.rect = r;
        o.state = s;
        if (s & QStyle::State_MouseOver)
            QCursor::setPos(w->mapToGlobal(w->rect().center()));
        if (!(s & QStyle::State_Active))
            o.palette.setCurrentColorGroup(QPalette::Inactive);
        if (!(s & QStyle::State_Enabled))
            o.palette.setCurrentColorGroup(QPalette::Disabled);
    };
    const auto pushLike = [&](bool def, bool on) -> Draw {
        return [=, &st](QPainter &p, QRect r, S s) {
            QPushButton *b = def ? defaultPush : push;
            QStyleOptionButton o;
            withPalette(o, b, r.adjusted(8, 7, -8, -7), s | (on ? QStyle::State_On : QStyle::State_Off));
            o.text = QStringLiteral("Bouton");
            if (def)
                o.features |= QStyleOptionButton::DefaultButton;
            st->drawControl(QStyle::CE_PushButton, &o, &p, b);
        };
    };
    const auto toolLike = [&](QToolButton *b, bool autoRaise, bool on) -> Draw {
        return [=, &st](QPainter &p, QRect r, S s) {
            QStyleOptionToolButton o;
            withPalette(o, b, r.adjusted(30, 7, -30, -7), s | (on ? QStyle::State_On : QStyle::State_Off));
            if (autoRaise)
                o.state |= QStyle::State_AutoRaise;
            if (!(s & QStyle::State_Sunken) && !on)
                o.state |= QStyle::State_Raised;
            o.subControls = QStyle::SC_ToolButton;
            o.activeSubControls = (s & (QStyle::State_MouseOver | QStyle::State_Sunken)) ? QStyle::SC_ToolButton : QStyle::SC_None;
            o.toolButtonStyle = Qt::ToolButtonTextOnly;
            o.text = QStringLiteral("Outil");
            o.arrowType = Qt::NoArrow;
            st->drawComplexControl(QStyle::CC_ToolButton, &o, &p, b);
        };
    };
    const auto boxLike = [&](QWidget *w, QStyle::ControlElement ce, bool on, const QString &text) -> Draw {
        return [=, &st](QPainter &p, QRect r, S s) {
            QStyleOptionButton o;
            withPalette(o, w, r.adjusted(14, 10, -14, -10), s | (on ? QStyle::State_On : QStyle::State_Off));
            o.text = text;
            st->drawControl(ce, &o, &p, w);
        };
    };

    const auto tabRow = [&](bool selected) -> Draw {
        return [=, &st](QPainter &p, QRect r, S s) {
            QStyleOptionTab o;
            withPalette(o, tabs, r.adjusted(8, 7, -8, -7), selected ? s | QStyle::State_Selected : s);
            o.text = QStringLiteral("Onglet");
            o.position = QStyleOptionTab::OnlyOneTab;
            o.shape = QTabBar::RoundedNorth;
            st->drawControl(QStyle::CE_TabBarTab, &o, &p, tabs);
        };
    };
    const auto lineRow = [&](bool selected) -> Draw {
        return [=, &st](QPainter &p, QRect r, S s) {
            QStyleOptionViewItem o;
            withPalette(o, list->viewport(), r.adjusted(6, 8, -6, -8), selected ? s | QStyle::State_Selected : s);
            o.features |= QStyleOptionViewItem::HasDisplay;
            o.text = QStringLiteral("Ligne");
            o.displayAlignment = Qt::AlignCenter;
            o.widget = list;
            st->drawControl(QStyle::CE_ItemViewItem, &o, &p, list);
        };
    };

    const QList<QPair<QString, Draw>> rows = {
        {QStringLiteral("Bouton"), pushLike(false, false)},
        {QStringLiteral("Bouton par défaut"), pushLike(true, false)},
        {QStringLiteral("Bouton activé"), pushLike(false, true)},
        {QStringLiteral("Outil (barre)"), toolLike(tool, true, false)},
        {QStringLiteral("Outil activé (barre)"), toolLike(tool, true, true)},
        {QStringLiteral("Outil simple"), toolLike(plainTool, false, false)},
        {QStringLiteral("Liste déroulante"), [&](QPainter &p, QRect r, S s) {
             QStyleOptionComboBox o;
             withPalette(o, combo, r.adjusted(8, 7, -8, -7), s);
             o.subControls = QStyle::SC_All;
             o.currentText = QStringLiteral("Liste");
             if (s & QStyle::State_HasFocus)  // comme QComboBox::initStyleOption
                 o.state |= QStyle::State_Selected;
             o.frame = true;
             o.activeSubControls = (s & (QStyle::State_MouseOver | QStyle::State_Sunken)) ? QStyle::SC_ComboBoxFrame : QStyle::SC_None;
             st->drawComplexControl(QStyle::CC_ComboBox, &o, &p, combo);
             st->drawControl(QStyle::CE_ComboBoxLabel, &o, &p, combo);
         }},
        {QStringLiteral("Champ"), [&](QPainter &p, QRect r, S s) {
             QStyleOptionFrame o;
             withPalette(o, edit, r.adjusted(8, 7, -8, -7), s);
             o.lineWidth = st->pixelMetric(QStyle::PM_DefaultFrameWidth, &o, edit);
             st->drawPrimitive(QStyle::PE_PanelLineEdit, &o, &p, edit);
         }},
        {QStringLiteral("Case décochée"), boxLike(check, QStyle::CE_CheckBox, false, QStringLiteral("Case"))},
        {QStringLiteral("Case cochée"), boxLike(check, QStyle::CE_CheckBox, true, QStringLiteral("Case"))},
        {QStringLiteral("Radio coché"), boxLike(radio, QStyle::CE_RadioButton, true, QStringLiteral("Choix"))},
        {QStringLiteral("Onglet"), tabRow(false)},
        {QStringLiteral("Onglet sélectionné"), tabRow(true)},
        {QStringLiteral("Élément de menu"), [&](QPainter &p, QRect r, S s) {
             p.fillRect(r.adjusted(4, 4, -4, -4), QColor(0x1e, 0x1e, 0x2e));
             QStyleOptionMenuItem o;
             withPalette(o, menu, r.adjusted(4, 7, -4, -7), s);
             if (s & (QStyle::State_MouseOver | QStyle::State_Sunken))
                 o.state |= QStyle::State_Selected;
             o.menuItemType = QStyleOptionMenuItem::Normal;
             o.text = QStringLiteral("Élément");
             st->drawControl(QStyle::CE_MenuItem, &o, &p, menu);
         }},
        {QStringLiteral("Ligne de liste"), lineRow(false)},
        {QStringLiteral("Ligne sélectionnée"), lineRow(true)},
        {QStringLiteral("Curseur"), [&](QPainter &p, QRect r, S s) {
             QStyleOptionSlider o;
             withPalette(o, slider, r.adjusted(10, 10, -10, -10), s | QStyle::State_Horizontal);
             o.orientation = Qt::Horizontal;
             o.minimum = 0;
             o.maximum = 100;
             o.sliderPosition = o.sliderValue = 55;
             o.subControls = QStyle::SC_SliderGroove | QStyle::SC_SliderHandle;
             o.activeSubControls = (s & (QStyle::State_MouseOver | QStyle::State_Sunken)) ? QStyle::SC_SliderHandle : QStyle::SC_None;
             st->drawComplexControl(QStyle::CC_Slider, &o, &p, slider);
         }},
        {QStringLiteral("Progression"), [&](QPainter &p, QRect r, S s) {
             QStyleOptionProgressBar o;
             withPalette(o, progress, r.adjusted(10, 14, -10, -14), s | QStyle::State_Horizontal);
             o.minimum = 0;
             o.maximum = 100;
             o.progress = 55;
             st->drawControl(QStyle::CE_ProgressBar, &o, &p, progress);
         }},
        {QStringLiteral("Barre de défilement"), [&](QPainter &p, QRect r, S s) {
             QStyleOptionSlider o;
             withPalette(o, scroll, r.adjusted(8, 12, -8, -12), s | QStyle::State_Horizontal);
             o.orientation = Qt::Horizontal;
             o.minimum = 0;
             o.maximum = 100;
             o.pageStep = 40;
             o.sliderPosition = o.sliderValue = 30;
             o.subControls = QStyle::SC_ScrollBarGroove | QStyle::SC_ScrollBarSlider;
             o.activeSubControls = (s & (QStyle::State_MouseOver | QStyle::State_Sunken)) ? QStyle::SC_ScrollBarSlider : QStyle::SC_None;
             st->drawComplexControl(QStyle::CC_ScrollBar, &o, &p, scroll);
         }},
    };

    const S on = QStyle::State_Enabled | QStyle::State_Active;
    const QList<Column> columns = {
        {"Repos", on},
        {"Survol", on | QStyle::State_MouseOver},
        {"Appui", on | QStyle::State_MouseOver | QStyle::State_Sunken},
        {"Focus clavier", on | QStyle::State_HasFocus | QStyle::State_KeyboardFocusChange},
        {"Focus souris", on | QStyle::State_HasFocus},
        {"Fenêtre inactive", QStyle::State_Enabled, true},
        {"Désactivé", QStyle::State_Active},
    };

    QImage shot(labelW + cellW * columns.size(), headH + cellH * rows.size(), QImage::Format_ARGB32_Premultiplied);
    shot.fill(win.palette().color(QPalette::Active, QPalette::Window));
    QPainter p(&shot);
    p.setPen(win.palette().color(QPalette::Active, QPalette::WindowText));
    for (int c = 0; c < columns.size(); ++c) {
        if (columns[c].inactive) {
            other.show();
            QApplication::setActiveWindow(&other);
            settle(200);
        }
        p.drawText(QRect(labelW + c * cellW, 0, cellW, headH), Qt::AlignCenter, QString::fromUtf8(columns[c].name));
        for (int r = 0; r < rows.size(); ++r) {
            const QRect cell(labelW + c * cellW, headH + r * cellH, cellW, cellH);
            p.save();
            p.setClipRect(cell);
            rows[r].second(p, cell, columns[c].state);
            p.restore();
        }
        if (columns[c].inactive) {
            other.hide();
            QApplication::setActiveWindow(&win);
            settle(200);
        }
    }
    for (int r = 0; r < rows.size(); ++r)
        p.drawText(QRect(10, headH + r * cellH, labelW - 10, cellH), Qt::AlignVCenter, rows[r].first);
    p.end();
    delete menu;
    if (!shot.scaled(shot.size() * 2, Qt::IgnoreAspectRatio, Qt::FastTransformation).save(QString::fromLocal8Bit(argv[3])))
        return 1;
    return 0;
}
