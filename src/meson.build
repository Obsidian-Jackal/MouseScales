sources = files(
  'main.vala',
  'application.vala',
  'window.vala',
  'pointer_control.vala',
  'startup_install.vala',
  'session_detect.vala',
  'wayland_backend.vala',
)

executable(
  'mouse-scales',
  sources,
  dependencies: [gtk_dep],
  vala_args: ['--pkg=posix'],
  install: true,
)
