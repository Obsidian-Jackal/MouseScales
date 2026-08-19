project(
  'mouse-scales',
  ['c', 'vala'],
  version: '0.1.0',
  meson_version: '>= 0.59.0',
  default_options: [
    'warning_level=1',
    'buildtype=debugoptimized',
  ],
)

dependency('glib-2.0', version: '>= 2.76')
dependency('gobject-2.0')
dependency('gio-2.0')
gtk_dep = dependency('gtk4', version: '>= 4.12')

subdir('data')
subdir('src')

gnome = import('gnome')
gnome.post_install(
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
