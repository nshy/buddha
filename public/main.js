$(document).ready(function() {
    $.scrollUp({
      scrollTrigger: '<a id="scrollUp" href="#top" class="push"/>'
    });
    // order is significant as scroll up has to be pushed too
    $('.menu-link').bigSlide({
      side: 'right'
    });
});
