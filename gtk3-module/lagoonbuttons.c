// Les boutons de fenêtre des applis GTK 3 s'allument ensemble au survol. GTK 3 ne donne
// :hover qu'au bouton survolé, et son CSS ne sait viser ni le parent ni les frères précédents :
// ce module pose la classe .lagoon-hover sur la boîte des boutons tant que le pointeur y est.
// Le CSS du thème (build-gtk.py) fait le reste ; sans le module, ils réagissent un par un.
// Chargé par GTK3_MODULES, voir install.sh.
#include <gtk/gtk.h>

#define HOVER_CLASS "lagoon-hover"
#define TIMER_KEY "lagoon-hover-timer"
#define POLL_MS 40

static gboolean pointer_inside (GtkWidget *box)
{
  GdkWindow *window = gtk_widget_get_window (box);
  GdkDevice *pointer = gdk_seat_get_pointer (gdk_display_get_default_seat (gdk_window_get_display (window)));
  GtkAllocation area;
  int x, y, box_x, box_y;

  // hors de toute fenêtre de l'appli, la dernière position connue ne veut plus rien dire
  if (!gdk_device_get_window_at_position (pointer, NULL, NULL))
    return FALSE;
  gdk_window_get_device_position (gdk_window_get_toplevel (window), pointer, &x, &y, NULL);
  if (!gtk_widget_translate_coordinates (box, gtk_widget_get_toplevel (box), 0, 0, &box_x, &box_y))
    return FALSE;
  gtk_widget_get_allocation (box, &area);
  return x >= box_x && x < box_x + area.width && y >= box_y && y < box_y + area.height;
}

// entre deux boutons, le pointeur a quitté l'un sans entrer dans l'autre : la boîte reste
// allumée tant qu'il est dedans
static gboolean check_still_inside (gpointer data)
{
  GtkWidget *box = data;

  if (gtk_widget_get_realized (box) && pointer_inside (box))
    return G_SOURCE_CONTINUE;
  gtk_style_context_remove_class (gtk_widget_get_style_context (box), HOVER_CLASS);
  g_object_set_data (G_OBJECT (box), TIMER_KEY, NULL);
  return G_SOURCE_REMOVE;
}

static gboolean on_crossing (GSignalInvocationHint *hint, guint n_values, const GValue *values, gpointer entering)
{
  GObject *object = g_value_get_object (&values[0]);
  GtkWidget *box;

  if (!GTK_IS_BUTTON (object)
      || !gtk_style_context_has_class (gtk_widget_get_style_context (GTK_WIDGET (object)), "titlebutton"))
    return TRUE;
  box = gtk_widget_get_parent (GTK_WIDGET (object));
  if (!box)
    return TRUE;
  if (GPOINTER_TO_INT (entering))
    gtk_style_context_add_class (gtk_widget_get_style_context (box), HOVER_CLASS);
  else if (!g_object_get_data (G_OBJECT (box), TIMER_KEY))
    g_object_set_data (G_OBJECT (box), TIMER_KEY,
                       GUINT_TO_POINTER (g_timeout_add_full (G_PRIORITY_DEFAULT, POLL_MS, check_still_inside,
                                                             g_object_ref (box), g_object_unref)));
  return TRUE;
}

// les crochets de signaux restent posés : le module ne doit pas être déchargé
G_MODULE_EXPORT const gchar *g_module_check_init (GModule *module)
{
  g_module_make_resident (module);
  return NULL;
}

G_MODULE_EXPORT void gtk_module_init (gint *argc, gchar ***argv)
{
  gpointer widget_class = g_type_class_ref (GTK_TYPE_WIDGET);

  g_signal_add_emission_hook (g_signal_lookup ("enter-notify-event", GTK_TYPE_WIDGET), 0, on_crossing, GINT_TO_POINTER (TRUE), NULL);
  g_signal_add_emission_hook (g_signal_lookup ("leave-notify-event", GTK_TYPE_WIDGET), 0, on_crossing, GINT_TO_POINTER (FALSE), NULL);
  g_type_class_unref (widget_class);
}
