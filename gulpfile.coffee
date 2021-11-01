gulp = require 'gulp'
gulpCoffee = require 'gulp-coffee'
gulpPug = require 'gulp-pug'
gulpChmod = require 'gulp-chmod'
child_process = require 'child_process'

## npm run pug / npx gulp pug: builds index.html from index.pug etc.
exports.pug = pug = ->
  gulp.src '*.pug'
  .pipe gulpPug pretty: true
  .pipe gulpChmod 0o644
  .pipe gulp.dest './'

## npm run coffee / npx gulp coffee: builds index.js from index.coffee etc.
exports.coffee = coffee = ->
  gulp.src '*.coffee', ignore: 'gulpfile.coffee'
  .pipe gulpCoffee()
  .pipe gulpChmod 0o644
  .pipe gulp.dest './'

## npm run font / npx gulp font: builds font.js from allfont.coffee via
## `coffee voronoi.coffee`
exports.font = font = ->
  child_process.exec 'coffee voronoi.coffee'

## npm run build / npx gulp build: all of the above
exports.build = build = gulp.series pug, coffee, font

## npm run watch / npx gulp watch: continuously update above
exports.watch = watch = ->
  gulp.watch '*.pug', ignoreInitial: false, pug
  gulp.watch '*.coffee',
    ignore: 'gulpfile.coffee'
    ignoreInitial: false
  , coffee
  gulp.watch ['allfont.coffee', 'voronoi.coffee'], ignoreInitial: false, font

exports.default = pug
