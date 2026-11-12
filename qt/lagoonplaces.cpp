// Le texte de la sélection reste lisible dans le panneau Emplacements de KIO (Dolphin, boîtes de
// dialogue de fichiers). Qt retire State_Active aux vues sans focus, et KIO écrit alors la
// sélection en texte normal, clair, illisible sur l'accent. Ce plugin le lui rend, pour ce
// panneau seulement : KIO choisit alors le texte de sélection, sombre.
// Chargé par QT_QPA_GENERIC_PLUGINS, voir install.sh.
#include <QAbstractItemDelegate>
#include <QAbstractItemView>
#include <QApplication>
#include <QEvent>
#include <QGenericPlugin>
#include <QHelpEvent>
#include <QPointer>
#include <QStyle>
#include <QStyleOptionViewItem>

class ActiveDelegate : public QAbstractItemDelegate
{
    Q_OBJECT
public:
    ActiveDelegate(QAbstractItemDelegate *inner, QObject *parent) : QAbstractItemDelegate(parent), m_inner(inner) {}
    void paint(QPainter *p, const QStyleOptionViewItem &o, const QModelIndex &i) const override
    {
        QStyleOptionViewItem opt(o);
        opt.state |= QStyle::State_Active;
        m_inner->paint(p, opt, i);
    }
    QSize sizeHint(const QStyleOptionViewItem &o, const QModelIndex &i) const override { return m_inner->sizeHint(o, i); }
    QWidget *createEditor(QWidget *w, const QStyleOptionViewItem &o, const QModelIndex &i) const override { return m_inner->createEditor(w, o, i); }
    void setEditorData(QWidget *e, const QModelIndex &i) const override { m_inner->setEditorData(e, i); }
    void setModelData(QWidget *e, QAbstractItemModel *m, const QModelIndex &i) const override { m_inner->setModelData(e, m, i); }
    void updateEditorGeometry(QWidget *e, const QStyleOptionViewItem &o, const QModelIndex &i) const override { m_inner->updateEditorGeometry(e, o, i); }
    bool editorEvent(QEvent *e, QAbstractItemModel *m, const QStyleOptionViewItem &o, const QModelIndex &i) override { return m_inner->editorEvent(e, m, o, i); }
    bool helpEvent(QHelpEvent *e, QAbstractItemView *v, const QStyleOptionViewItem &o, const QModelIndex &i) override { return m_inner->helpEvent(e, v, o, i); }
private:
    QPointer<QAbstractItemDelegate> m_inner;
};

class Watcher : public QObject
{
public:
    using QObject::QObject;
    bool eventFilter(QObject *o, QEvent *e) override
    {
        if (e->type() == QEvent::Polish && o->inherits("KFilePlacesView")) {
            auto *view = static_cast<QAbstractItemView *>(o);
            // pas setItemDelegate : KIO relit itemDelegate() en supposant que c'est le sien
            if (auto *inner = view->itemDelegate(); inner && !view->itemDelegateForColumn(0))
                view->setItemDelegateForColumn(0, new ActiveDelegate(inner, view));
        }
        return false;
    }
};

class Plugin : public QGenericPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QGenericPluginFactoryInterface_iid FILE "lagoonplaces.json")
public:
    QObject *create(const QString &, const QString &) override
    {
        auto *w = new Watcher; // Qt le détruit lui-même, à la fin de l'appli : pas de parent
        qApp->installEventFilter(w);
        return w;
    }
};
#include "lagoonplaces.moc"
