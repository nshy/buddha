'use strict';

var gulp = require('gulp');
var sass = require('gulp-sass');
var concat = require('gulp-concat');
var deleted = require('gulp-deleted2');
var rename = require('gulp-rename');
var newer = require('gulp-newer');
var newer_sass = require('gulp-newer-sass');

gulp.task('sass-data', function () {
  return gulp.src('./data/**/*.scss')
          .pipe(newer({dest: './data', ext: '.css'}))
          .pipe(sass().on('error', sass.logError))
          .pipe(gulp.dest('./data'));
});

gulp.task('sass-purge', function () {
  return gulp.src('./assets/css/**/*.scss')
          .pipe(rename(function(path) {
            path.extname = '.css';
          }))
          .pipe(deleted('./public/css', '*'));
});

gulp.task('sass', ['sass-purge'], function () {
  return gulp.src('./assets/css/**/*.scss')
          .pipe(newer_sass({dest: './public/css'}))
          .pipe(sass().on('error', sass.logError))
          .pipe(gulp.dest('./public/css'));
});

gulp.task('concat', ['sass'], function () {
  return gulp.src(['public/css/*.css'])
          .pipe(newer('public/bundle.css'))
          .pipe(concat('bundle.css'))
          .pipe(gulp.dest('./public'));
});

gulp.task('css', ['concat', 'sass-data'])

gulp.task('default', function () {
  gulp.watch('./assets/css/**/*.scss', ['concat']);
  gulp.watch('./data/**/*.scss', ['sass-data']);
});
