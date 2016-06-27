// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
// DISABLE = require turbolinks
//
// Required by Blacklight
//= require blacklight/blacklight
//= require blacklight_range_limit
//= require_tree .

// http://stackoverflow.com/a/30008017
$(function() {$.support.transition = false;});
// When facet selectors expand, they were bumping the reset of the window.
// "position: absolute" isn't a good fix, because the animation is all about
// repositioning: "absolute" just hides it for the length of the animation.