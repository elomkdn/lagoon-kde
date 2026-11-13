// Les applis GTK 3 floutées derrière leurs fenêtres, comme les applis Qt (Kvantum). KWin ne
// floute que derrière les fenêtres qui le demandent, et GTK ne le demande jamais : ce code le
// fait à sa place, pour chaque fenêtre de premier niveau, par le protocole standard
// (vendor/wayland-protocols/ext-background-effect-v1.xml, KWin 6.8 et après) ou, à défaut, par
// celui de KDE (vendor/plasma-wayland-protocols/blur.xml, avant). Tant que KWin floute (l'effet
// Flou est actif : il l'annonce), le module ajoute lagoon-blur.css, à côté de lui, au thème :
// le fond des fenêtres passe de 95 % (sans flou, gtk-3.0/gtk.css) à 80 %, comme celui des
// applis Qt ; il le retire si l'effet est coupé.
//
// La région floutée : toute la fenêtre quand KWin la décore (il l'arrondit lui-même, flou
// compris) ; sinon (décoration dessinée par GTK) la fenêtre sans son ombre, aux coins arrondis
// comme les siens (en haut seulement, sauf fenêtre .unified), sauf maximisée, en mosaïque ou en
// plein écran.
//
// Wayland seulement ; les menus, popovers et infobulles restent opaques.
#include <gtk/gtk.h>
#include <gdk/gdkwayland.h>
#include <math.h>
#include "blur-client-protocol.h"
#include "ext-background-effect-v1-client-protocol.h"

#define BLUR_KEY "lagoon-blur"
#define TRACKED_KEY "lagoon-blur-tracked"
#define WINDOW_RADIUS 15     // les coins des fenêtres dans adw-gtk3 (window.csd), comme Klassy
#define THEME "Lagoon"

typedef struct {
  struct ext_background_effect_surface_v1 *effect;   // l'un ou l'autre, selon le protocole
  struct org_kde_kwin_blur *blur;
  struct wl_surface *surface;
  GdkRectangle area;
  int top, bottom;     // rayons des coins du haut et du bas
} Blur;

static struct ext_background_effect_manager_v1 *effects;
static struct org_kde_kwin_blur_manager *kde_blur;
static gboolean initialized;
static gboolean blurring;          // KWin floute : il l'annonce, au départ et à chaque changement
static GtkCssProvider *provider;
static GdkScreen *screen;

static void set_blurring (gboolean on)
{
  if (on == blurring)
    return;
  blurring = on;
  // au-dessus du thème et des réglages (au rang du thème, ses règles ne passent pas devant
  // celles de gtk-3.0/gtk.css), au-dessous du CSS des applis et de l'utilisateur
  if (on)
    gtk_style_context_add_provider_for_screen (screen, GTK_STYLE_PROVIDER (provider),
                                               GTK_STYLE_PROVIDER_PRIORITY_SETTINGS + 1);
  else
    gtk_style_context_remove_provider_for_screen (screen, GTK_STYLE_PROVIDER (provider));
}

static void capabilities (void *data, struct ext_background_effect_manager_v1 *manager, uint32_t flags)
{
  set_blurring ((flags & EXT_BACKGROUND_EFFECT_MANAGER_V1_CAPABILITY_BLUR) != 0);
}

static const struct ext_background_effect_manager_v1_listener effects_listener = { capabilities };

static void global (void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
  if (g_strcmp0 (interface, ext_background_effect_manager_v1_interface.name) == 0) {
    effects = wl_registry_bind (registry, name, &ext_background_effect_manager_v1_interface, 1);
    ext_background_effect_manager_v1_add_listener (effects, &effects_listener, NULL);
  } else if (g_strcmp0 (interface, org_kde_kwin_blur_manager_interface.name) == 0) {
    kde_blur = wl_registry_bind (registry, name, &org_kde_kwin_blur_manager_interface, 1);
  }
}

static void global_remove (void *data, struct wl_registry *registry, uint32_t name) {}

static const struct wl_registry_listener registry_listener = { global, global_remove };

// les protocoles de flou, cherchés sur une file d'événements à part : celle de GDK n'est pas à nous
static void init_display (GdkDisplay *display)
{
  struct wl_display *wl, *wrapper;
  struct wl_event_queue *queue;
  struct wl_registry *registry;
  gchar *theme = NULL;

  initialized = TRUE;
  g_object_get (gtk_settings_get_default (), "gtk-theme-name", &theme, NULL);
  if (g_strcmp0 (theme, THEME) != 0 || !GDK_IS_WAYLAND_DISPLAY (display)) {
    g_free (theme);
    return;
  }
  g_free (theme);

  screen = gdk_display_get_default_screen (display);
  wl = gdk_wayland_display_get_wl_display (display);
  queue = wl_display_create_queue (wl);
  wrapper = wl_proxy_create_wrapper (wl);
  wl_proxy_set_queue ((struct wl_proxy *) wrapper, queue);
  registry = wl_display_get_registry (wrapper);
  wl_proxy_wrapper_destroy (wrapper);
  wl_registry_add_listener (registry, &registry_listener, NULL);
  wl_display_roundtrip_queue (wl, queue);   // les globales
  wl_registry_destroy (registry);
  if (effects) {
    if (kde_blur) {                         // le protocole standard suffit
      org_kde_kwin_blur_manager_destroy (kde_blur);
      kde_blur = NULL;
    }
    wl_display_roundtrip_queue (wl, queue); // ses capacités
    // les suivantes (effet Flou coupé ou remis) arrivent avec les événements de GDK
    wl_proxy_set_queue ((struct wl_proxy *) effects, NULL);
  } else if (kde_blur) {
    wl_proxy_set_queue ((struct wl_proxy *) kde_blur, NULL);
    set_blurring (TRUE);                    // KWin n'annonce ce protocole que s'il floute
  }
  wl_event_queue_destroy (queue);
}

static void release (Blur *b)
{
  if (b->effect)
    ext_background_effect_surface_v1_destroy (b->effect);
  if (b->blur)
    org_kde_kwin_blur_release (b->blur);
  g_free (b);
}

// retrait d'une rangée de pixels sous l'arrondi de rayon r : ceux qu'il couvre en entier
static int inset (int r, int i)
{
  double dy = r - i;
  return (int) ceil (r - sqrt ((double) r * r - dy * dy));
}

static void add_rounded (struct wl_region *region, GdkRectangle *a, int top, int bottom)
{
  wl_region_add (region, a->x, a->y + top, a->width, a->height - top - bottom);
  for (int i = 0; i < top; i++)
    wl_region_add (region, a->x + inset (top, i), a->y + i, a->width - 2 * inset (top, i), 1);
  for (int i = 0; i < bottom; i++)
    wl_region_add (region, a->x + inset (bottom, i), a->y + a->height - 1 - i, a->width - 2 * inset (bottom, i), 1);
}

// la place d'un enfant de la fenêtre, ses marges comprises (son allocation ne les compte pas)
static void union_allocation (GtkWidget *widget, GdkRectangle *area, gboolean *found)
{
  GtkAllocation a;

  if (!widget || !gtk_widget_get_visible (widget))
    return;
  gtk_widget_get_allocation (widget, &a);
  a.x -= gtk_widget_get_margin_start (widget);
  a.y -= gtk_widget_get_margin_top (widget);
  a.width += gtk_widget_get_margin_start (widget) + gtk_widget_get_margin_end (widget);
  a.height += gtk_widget_get_margin_top (widget) + gtk_widget_get_margin_bottom (widget);
  if (*found)
    gdk_rectangle_union (area, &a, area);
  else
    *area = a;
  *found = TRUE;
}

static void update (GtkWidget *window)
{
  GdkWindow *gdk_window = gtk_widget_get_window (window);
  struct wl_surface *surface;
  Blur *b = g_object_get_data (G_OBJECT (window), BLUR_KEY);
  GdkRectangle area = { 0, 0, gtk_widget_get_allocated_width (window), gtk_widget_get_allocated_height (window) };
  int top = 0, bottom = 0;

  if (!(effects || kde_blur) || !gdk_window || !gtk_widget_get_mapped (window)
      || !(surface = gdk_wayland_window_get_wl_surface (gdk_window)))
    return;
  if (b && b->surface != surface) {
    g_object_set_data (G_OBJECT (window), BLUR_KEY, NULL);
    b = NULL;
  }

  // décoration dessinée par GTK : la fenêtre sans son ombre, celle de sa barre de titre et de
  // son contenu, aux coins arrondis
  GtkStyleContext *style = gtk_widget_get_style_context (window);
  if (gtk_style_context_has_class (style, "csd")) {
    gboolean found = FALSE;
    union_allocation (gtk_window_get_titlebar (GTK_WINDOW (window)), &area, &found);
    union_allocation (gtk_bin_get_child (GTK_BIN (window)), &area, &found);
    if (!(gdk_window_get_state (gdk_window) & (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN
                                               | GDK_WINDOW_STATE_TILED | GDK_WINDOW_STATE_TOP_TILED
                                               | GDK_WINDOW_STATE_BOTTOM_TILED | GDK_WINDOW_STATE_LEFT_TILED
                                               | GDK_WINDOW_STATE_RIGHT_TILED))) {
      top = MIN (WINDOW_RADIUS, MIN (area.width, area.height) / 2);
      bottom = gtk_style_context_has_class (style, "unified") ? top : 0;
    }
  }

  if (!b) {
    b = g_new0 (Blur, 1);
    b->surface = surface;
    if (effects)
      b->effect = ext_background_effect_manager_v1_get_background_effect (effects, surface);
    else
      b->blur = org_kde_kwin_blur_manager_create (kde_blur, surface);
    b->top = -1;
    g_object_set_data_full (G_OBJECT (window), BLUR_KEY, b, (GDestroyNotify) release);
  } else if (gdk_rectangle_equal (&b->area, &area) && b->top == top && b->bottom == bottom) {
    return;
  }
  b->area = area;
  b->top = top;
  b->bottom = bottom;

  struct wl_region *region =
    wl_compositor_create_region (gdk_wayland_display_get_wl_compositor (gdk_window_get_display (gdk_window)));
  add_rounded (region, &area, top, bottom);
  if (b->effect) {
    ext_background_effect_surface_v1_set_blur_region (b->effect, region);
  } else {
    org_kde_kwin_blur_set_region (b->blur, region);
    org_kde_kwin_blur_commit (b->blur);
  }
  wl_region_destroy (region);
  // la région s'applique à la prochaine image de la fenêtre
  gtk_widget_queue_draw (window);
}

static void on_size_allocate (GtkWidget *window, GdkRectangle *allocation, gpointer data)
{
  update (window);
}

static gboolean on_window_state (GtkWidget *window, GdkEventWindowState *event, gpointer data)
{
  update (window);
  return FALSE;
}

// GDK peut détruire la surface d'une fenêtre cachée : l'objet de flou part avant elle (une
// requête sur une surface détruite est une erreur du protocole, qui coûterait l'appli)
static void on_unmap (GtkWidget *window, gpointer data)
{
  g_object_set_data (G_OBJECT (window), BLUR_KEY, NULL);
}

static gboolean update_later (gpointer window)
{
  update (window);
  return G_SOURCE_REMOVE;
}

static gboolean on_map (GSignalInvocationHint *hint, guint n_values, const GValue *values, gpointer data)
{
  GObject *object = g_value_get_object (&values[0]);

  if (!GTK_IS_WINDOW (object) || gtk_window_get_window_type (GTK_WINDOW (object)) != GTK_WINDOW_TOPLEVEL)
    return TRUE;
  if (!initialized)
    init_display (gtk_widget_get_display (GTK_WIDGET (object)));
  if (!(effects || kde_blur))
    return TRUE;
  if (!g_object_get_data (object, TRACKED_KEY)) {
    g_object_set_data (object, TRACKED_KEY, GINT_TO_POINTER (TRUE));
    g_signal_connect_after (object, "size-allocate", G_CALLBACK (on_size_allocate), NULL);
    g_signal_connect_after (object, "window-state-event", G_CALLBACK (on_window_state), NULL);
    g_signal_connect (object, "unmap", G_CALLBACK (on_unmap), NULL);
  }
  // une fois la fenêtre montrée : sa surface a alors son rôle
  g_idle_add_full (G_PRIORITY_DEFAULT, update_later, g_object_ref (object), g_object_unref);
  return TRUE;
}

void lagoon_blur_init (const gchar *module_path)
{
  gchar *dir = g_path_get_dirname (module_path);
  gchar *path = g_build_filename (dir, "lagoon-blur.css", NULL);

  provider = gtk_css_provider_new ();
  if (gtk_css_provider_load_from_path (provider, path, NULL))
    g_signal_add_emission_hook (g_signal_lookup ("map", GTK_TYPE_WIDGET), 0, on_map, NULL, NULL);
  g_free (path);
  g_free (dir);
}
