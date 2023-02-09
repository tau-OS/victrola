project('com.fyralabs.Victrola',
  ['c', 'vala'],
  version: '0.1.0',
  meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2', ],
)

gnome = import('gnome')
i18n = import('i18n')

if get_option('development')
  app_id = 'com.fyralabs.Victrola.Devel'
  name_suffix = ' (Nightly)'
else
  app_id = 'com.fyralabs.Victrola'
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

# Blueprint
subproject('blueprint-compiler')
add_project_arguments(
    '--gresourcesdir', meson.current_build_dir() / 'data',
    language: ['vala']
)
#

libm_dep = meson.get_compiler('c').find_library('m', required: false)
posix_dep = meson.get_compiler('c').find_library('posix', required: false)
libbismuth_dep = meson.get_compiler('c').find_library('libbismuth', required: false)

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
  dependency('libbismuth-1', fallback: [ 'libbismuth', 'libbismuth_dep' ], version: '>=1.0.0'),
  libm_dep,
  posix_dep,
  taglib_c_dep,
]

sources = [
  'src/Utils/gst-level.c',
  'src/Utils/ape-demux.c',

  'src/application.vala',
  'src/main.vala',
  'src/window.vala',
  'src/Utils/async-task.vala',
  'src/Utils/gst-player.vala',
  'src/Utils/mpris.vala',
  'src/Utils/song-store.vala',
  'src/Utils/tag-parser.vala',
  'src/Widgets/info-page.vala',
  'src/Widgets/play-bar.vala',
  'src/Widgets/song-entry.vala',
]

subdir('data')
subdir('po')

executable(
  'com.fyralabs.Victrola',
  asresources,
  sources: sources,
  vala_args: [
    meson.current_source_dir () + '/src/Utils' + '/config.vapi',
    meson.current_source_dir () + '/src/Utils' + '/gst-ext.vapi',
  ],
  dependencies: dependencies,
  install: true,
)

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
