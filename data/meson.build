conf = configuration_data()
conf.set('app_id', 'co.tauos.Victrola')
conf.set('version', version)
conf.set('bindir', get_option('prefix') / get_option('bindir'))

desktop_conf = configure_file(
  input: 'app.desktop.in',
  output: '@0@.desktop.in'.format('co.tauos.Victrola'),
  configuration: conf
)

desktop_file = i18n.merge_file(
  input: desktop_conf,
  output: '@0@.desktop'.format('co.tauos.Victrola'),
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: get_option('datadir') / 'applications'
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils,
    args: [desktop_file]
  )
endif

service_file = configure_file(
  input: 'app.service.in',
  output: '@0@.service'.format('co.tauos.Victrola'),
  configuration: conf,
)

install_data(
  service_file,
  install_dir: get_option('datadir') / 'dbus-1' / 'services'
)

appstream_conf = configure_file(
  input: 'app.appdata.xml.in',
  output: '@0@.appdata.xml.in'.format('co.tauos.Victrola'),
  configuration: conf
)

appstream_file = i18n.merge_file(
  input: appstream_conf,
  output: '@0@.appdata.xml'.format('co.tauos.Victrola'),
  po_dir: '../po',
  install: true,
  install_dir: get_option('datadir') / 'metainfo'
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('Validate appstream file', appstream_util,
    args: ['validate', '--nonet', appstream_file]
  )
endif

gschema_file = configure_file(
  input: 'app.gschema.xml',
  output: 'co.tauos.Victrola' + '.gschema.xml',
  configuration: conf,
)

install_data(
  gschema_file,
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

blueprints = custom_target(
  'blueprints',
  input: files(
    'ui/window.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)

asresources = gnome.compile_resources(
	'as-resources',
  'co.tauos.Victrola.gresource.xml',
	source_dir: meson.current_build_dir(),
  dependencies: blueprints,
	c_name: 'as',
  install_dir: get_option('datadir') / meson.project_name(),
)

subdir('icons')