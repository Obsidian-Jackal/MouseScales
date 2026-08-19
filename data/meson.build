conf = configuration_data()
conf.set('bindir', join_paths(get_option('prefix'), get_option('bindir')))

configure_file(
  input: 'mouse-scales.desktop.in',
  output: 'mouse-scales.desktop',
  configuration: conf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications'),
)

icon_sizes = ['16', '24', '32', '48', '64', '128', '256', '512']
foreach size : icon_sizes
  install_data(
    join_paths(
      'icons',
      'hicolor',
      size + 'x' + size,
      'apps',
      'org.obsidian_jackal.MouseScales.png',
    ),
    install_dir: join_paths(
      get_option('datadir'),
      'icons',
      'hicolor',
      size + 'x' + size,
      'apps',
    ),
  )
endforeach
