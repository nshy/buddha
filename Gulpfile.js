'use strict';

var gulp = require('gulp');
var sass = require('gulp-sass');
var concat = require('gulp-concat');

gulp.task('sass', function () {
  gulp.src('./assets/css/*.scss')
    .pipe(sass().on('error', sass.logError))
    .pipe(gulp.dest('./public/css'));
});

gulp.task('concat', function () {
  gulp.src(['public/css/*.css', '!public/css/bundle.css'])
    .pipe(concat('bundle.css'))
    .pipe(gulp.dest('./public/css'));
});

gulp.task('default', function () {
  gulp.watch('./assets/css/*.scss', ['sass', 'concat']);
});
