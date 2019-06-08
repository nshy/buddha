$(document).ready(function() {
    $.scrollUp({
      scrollTrigger: '<a id="scrollUp" href="#top" class="push"/>'
    });
    // order is significant as scroll up has to be pushed too
    $('.menu-link').bigSlide({
      side: 'right',
      easyClose: true
    });
    // set fotorama defaults
    $('.fotorama').fotorama({
      allowfullscreen: 'native',
      fit: 'scaledown'
    });
    $('.fotorama.quotes').fotorama({
      allowfullscreen: false
    });

    toCoordinates = function(s) {
      return s.split(',').map(function(v) { return Number.parseFloat(v); });
    }

    ymaps.ready(function() {
      document.querySelectorAll('.yandex-map').forEach(function(e) {
        placemark = toCoordinates(e.getAttribute('placemark'));
        offset = e.getAttribute('offset');
        if (offset) {
          offset = toCoordinates(offset);
          center = offset.map(function(v, i) {
            return v + placemark[i];
          });
        } else {
          center = placemark.slice();
        }
        zoom = Number.parseInt(e.getAttribute('zoom'), 10);
        caption = e.getAttribute('caption');
        hint = e.getAttribute('hint');
        balloon = e.getAttribute('balloon');
        console.log(balloon)

        var map = new ymaps.Map(e, {
                center: center,
                zoom: zoom,
            });
        map.behaviors.disable('scrollZoom');
        if (Modernizr.touchevents) {
          map.behaviors.disable('drag');
          fullscreen = map.controls.get('fullscreenControl')
          fullscreen.events.add('fullscreenenter', function() {
            this.behaviors.enable('drag');
          }, map);
          fullscreen.events.add('fullscreenexit', function() {
            this.behaviors.disable('drag');
          }, map);
        }

        map.geoObjects.add(
          new ymaps.Placemark(placemark,
           {  hintContent: hint,
              balloonContent: balloon }
        ));
      });
    });
});
