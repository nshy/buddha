'use strict';

var gulp = require('gulp');
var sass = require('gulp-sass');
var concat = require('gulp-concat');
var clean = require('gulp-clean');

gulp.task('clean', function () {
  return gulp.src('public/css/*')
          .pipe(clean({force: true}))
});

gulp.task('sass-data', function () {
  return gulp.src('./data/**/*.scss')
          .pipe(sass().on('error', sass.logError))
          .pipe(gulp.dest('./data'));
});

gulp.task('sass', ['clean'], function () {
  return gulp.src('./assets/css/**/*.scss')
          .pipe(sass().on('error', sass.logError))
          .pipe(gulp.dest('./public/css'));
});

gulp.task('concat', ['sass'], function () {
  return gulp.src(['public/css/*.css'])
          .pipe(concat('bundle.css'))
          .pipe(gulp.dest('./public'));
});

gulp.task('css', ['concat', 'sass-data'])

gulp.task('default', function () {
  gulp.watch('./assets/css/**/*.scss', ['concat']);
  gulp.watch('./data/**/*.scss', ['sass-data']);
});
