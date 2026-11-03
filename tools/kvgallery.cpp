// Galerie de widgets Qt rendue hors écran avec un thème Kvantum, pour comparer les versions
// d'un style sans ouvrir de fenêtre : boutons, champs, cases, curseur, onglets, liste avec
// sélection (active et inactive), menu et infobulle, dans une seule image.
// usage : kvgallery <dossier contenant le thème Kvantum> <nom du thème> <sortie.png>
// ex.  : kvgallery ~/.local/share/themes/Lagoon/Kvantum Lagoon galerie.png
#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFont>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMenu>
#include <QPainter>
#include <QProgressBar>
#include <QPushButton>
#include <QRadioButton>
#include <QSettings>
#include <QSlider>
#include <QSpinBox>
#include <QStandardPaths>
#include <QTabWidget>
#include <QTemporaryDir>
#include <QToolButton>
#include <QVBoxLayout>
#include <cstdio>

int main(int argc, char **argv)
{
    if (argc < 4) {
        std::fprintf(stderr, "usage : kvgallery <dossier du thème> <nom> <sortie.png>\n");
        return 1;
    }
    // police du bureau, comme dans gtkgallery ; pour QSettings, [General] est la racine du fichier,
    // et « Inter,12,… » une liste
    const QString font = QSettings(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                                       + QStringLiteral("/kdeglobals"), QSettings::IniFormat)
                             .value(QStringLiteral("font")).toStringList().join(QLatin1Char(','));
    // Kvantum lit son thème dans $XDG_CONFIG_HOME/Kvantum : on lui en donne un temporaire
    QTemporaryDir cfg;
    QDir(cfg.path()).mkpath(QStringLiteral("Kvantum"));
    QFile::link(QDir(QString::fromLocal8Bit(argv[1])).absolutePath(), cfg.path() + QStringLiteral("/Kvantum/") + QString::fromLocal8Bit(argv[2]));
    QFile kv(cfg.path() + QStringLiteral("/Kvantum/kvantum.kvconfig"));
    kv.open(QIODevice::WriteOnly);
    kv.write("[General]\ntheme=" + QByteArray(argv[2]) + "\n");
    kv.close();
    qputenv("XDG_CONFIG_HOME", cfg.path().toLocal8Bit());
    qputenv("QT_STYLE_OVERRIDE", "kvantum");
    QApplication app(argc, argv);
    QFont desktopFont;
    if (!font.isEmpty() && desktopFont.fromString(font))
        app.setFont(desktopFont);

    QWidget win;
    auto *grid = new QHBoxLayout(&win);
    auto *left = new QVBoxLayout;
    auto *right = new QVBoxLayout;
    grid->addLayout(left);
    grid->addLayout(right);

    auto *buttons = new QHBoxLayout;
    auto *normal = new QPushButton(QStringLiteral("Bouton"));
    auto *def = new QPushButton(QStringLiteral("Par défaut"));
    def->setDefault(true);
    auto *toggled = new QPushButton(QStringLiteral("Activé"));
    toggled->setCheckable(true);
    toggled->setChecked(true);
    auto *disabled = new QPushButton(QStringLiteral("Inactif"));
    disabled->setEnabled(false);
    auto *tool = new QToolButton;
    tool->setText(QStringLiteral("Outil"));
    tool->setAutoRaise(true);
    for (QWidget *w : {static_cast<QWidget *>(normal), static_cast<QWidget *>(def), static_cast<QWidget *>(toggled), static_cast<QWidget *>(disabled), static_cast<QWidget *>(tool)})
        buttons->addWidget(w);
    left->addLayout(buttons);

    auto *fields = new QHBoxLayout;
    auto *edit = new QLineEdit(QStringLiteral("Texte"));
    auto *empty = new QLineEdit;
    empty->setPlaceholderText(QStringLiteral("Rechercher…"));
    auto *combo = new QComboBox;
    combo->addItems({QStringLiteral("Liste déroulante"), QStringLiteral("Deux")});
    auto *spin = new QSpinBox;
    spin->setValue(42);
    for (QWidget *w : {static_cast<QWidget *>(edit), static_cast<QWidget *>(empty), static_cast<QWidget *>(combo), static_cast<QWidget *>(spin)})
        fields->addWidget(w);
    left->addLayout(fields);

    auto *checks = new QHBoxLayout;
    auto *c1 = new QCheckBox(QStringLiteral("Coché"));
    c1->setChecked(true);
    auto *c2 = new QCheckBox(QStringLiteral("Décoché"));
    auto *r1 = new QRadioButton(QStringLiteral("Choix 1"));
    r1->setChecked(true);
    auto *r2 = new QRadioButton(QStringLiteral("Choix 2"));
    for (QWidget *w : {static_cast<QWidget *>(c1), static_cast<QWidget *>(c2), static_cast<QWidget *>(r1), static_cast<QWidget *>(r2)})
        checks->addWidget(w);
    left->addLayout(checks);

    auto *slider = new QSlider(Qt::Horizontal);
    slider->setValue(60);
    left->addWidget(slider);
    auto *progress = new QProgressBar;
    progress->setValue(45);
    left->addWidget(progress);

    auto *tabs = new QTabWidget;
    auto *page = new QGroupBox(QStringLiteral("Groupe"));
    auto *pl = new QVBoxLayout(page);
    pl->addWidget(new QLabel(QStringLiteral("Contenu d'un onglet, dans un cadre.")));
    tabs->addTab(page, QStringLiteral("Onglet actif"));
    tabs->addTab(new QWidget, QStringLiteral("Autre"));
    left->addWidget(tabs);

    auto *list = new QListWidget;
    list->addItems({QStringLiteral("Documents"), QStringLiteral("Images (sélection)"), QStringLiteral("Musique"), QStringLiteral("Vidéos")});
    list->setCurrentRow(1);
    list->setFixedHeight(130);
    right->addWidget(list);
    auto *list2 = new QListWidget;
    list2->addItems({QStringLiteral("Bureau"), QStringLiteral("Téléchargements (inactive)")});
    list2->setCurrentRow(1);
    list2->setFixedHeight(70);
    right->addWidget(list2);

    win.resize(820, 420);
    win.show();
    // fenêtre active (sélection et focus dessinés comme à l'écran)
    win.activateWindow();
    list->setFocus();
    app.processEvents();
    QImage shot = win.grab().toImage();

    // menu et infobulle, rendus à part puis collés sous la fenêtre
    QMenu menu;
    menu.addAction(QStringLiteral("Ouvrir"));
    menu.addAction(QStringLiteral("Renommer"))->setCheckable(true);
    menu.addSeparator();
    menu.addAction(QStringLiteral("Supprimer"));
    menu.setActiveAction(menu.actions().first());
    menu.adjustSize();
    menu.show();
    app.processEvents();
    menu.setActiveAction(menu.actions().first());
    app.processEvents();
    QImage menuShot = menu.grab().toImage();
    QLabel tip(QStringLiteral("Une infobulle"), nullptr, Qt::ToolTip);
    tip.setForegroundRole(QPalette::ToolTipText);
    tip.setBackgroundRole(QPalette::ToolTipBase);
    tip.setMargin(6);
    tip.adjustSize();
    tip.show();
    app.processEvents();
    QImage tipShot = tip.grab().toImage();

    // champ avec le focus (anneau)
    win.activateWindow();
    edit->setFocus();
    // Kvantum anime le passage au focus : attendre la fin de l'animation
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < 600)
        app.processEvents(QEventLoop::AllEvents, 50);
    QImage editShot = edit->grab().toImage();

    QImage out(shot.width(), shot.height() + qMax(menuShot.height(), tipShot.height()) + 20, QImage::Format_ARGB32);
    out.fill(win.palette().color(QPalette::Window).darker(130));
    QPainter p(&out);
    p.drawImage(0, 0, shot);
    p.drawImage(20, shot.height() + 10, menuShot);
    p.drawImage(40 + menuShot.width(), shot.height() + 10, tipShot);
    p.drawImage(60 + menuShot.width() + tipShot.width(), shot.height() + 10, editShot);
    p.end();
    out.save(QString::fromLocal8Bit(argv[3]));
    return 0;
}
