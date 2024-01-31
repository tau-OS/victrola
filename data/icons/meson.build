scalable_dir = join_paths('hicolor', 'scalable', 'apps')
scalable_conf = configure_file(
  input: join_paths(scalable_dir, 'color.svg'),
  output: '@0@.svg'.format(app_id),
  configuration: conf
)

install_data(
  scalable_conf,
  install_dir: join_paths(get_option('datadir'), 'icons', scalable_dir)
)