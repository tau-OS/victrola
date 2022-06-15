project('co.tauos.Victrola',
  ['c', 'vala'],
  version: '0.1.0',
  meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2', ],
)

gnome = import('gnome')
i18n = import('i18n')

if get_option('development')
  app_id = 'co.tauos.Victrola.Devel'
  name_suffix = ' (Development)'
else
  app_id = 'co.tauos.Victrola'
  name_suffix = ''
endif

version = meson.project_version()

conf = configuration_data()
conf.set_quoted('APP_ID', app_id)
conf.set_quoted('NAME_SUFFIX', name_suffix)
conf.set_quoted('VERSION', version)
conf.set_quoted('GETTEXT_PACKAGE', app_id)
conf.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
conf.set10('DEVELOPMENT', get_option('development'))
configure_file(output: 'config.h', configuration: conf)

add_project_arguments('-DGETTEXT_PACKAGE="' + app_id + '"', language: 'c')

libm_dep = meson.get_compiler('c').find_library('m', required: false)

taglib_c_dep = dependency('taglib_c', required: false)
if taglib_c_dep.found()
  add_project_arguments('--define=HAS_TAGLIB_C', language: 'vala')
endif

dependencies = [
  dependency('gstreamer-1.0'),
  dependency('gstreamer-tag-1.0'),
  dependency('gtk4'),
  dependency('gee-0.8'),
  dependency('libhelium-1'),
  libm_dep,
  taglib_c_dep,
]

sources = [
  'src/Utils/gst-level.c',

  'src/application.vala',
  'src/main.vala',
  'src/Widgets/play-bar.vala',
  'src/Utils/async-task.vala',
  'src/Utils/gst-player.vala',
  'src/Utils/mpris.vala',
  'src/Utils/song-store.vala',
  'src/Utils/tag-parser.vala',
  'src/Widgets/song-entry.vala',
  'src/window.vala',
]

asresources = gnome.compile_resources(
	'as-resources', join_paths(meson.project_source_root(), 'data', 'co.tauos.Victrola.gresource.xml'),
	source_dir: join_paths(meson.project_source_root(), 'data'),
	c_name: 'as'
)

executable(
  'co.tauos.Victrola',
  sources,
  asresources,
  vala_args: [
    join_paths(meson.project_source_root(), 'src', 'Utils', 'config.vapi'),
  ],
  dependencies: dependencies,
  install: true,
)

subdir('data')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
