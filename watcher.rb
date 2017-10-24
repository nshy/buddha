#!/usr/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'
require_relative 'assets'
require_relative 'resources'

include CommonHelpers

$stdout.sync = true
sync_lock

module Watch

def listen_to(dir, options = {})
  l = Listen.to(dir.dir, relative: true) do |*d|
    d = d.map { |s| s.select { |p| dir.match(p) } }
    Cache.diffmsg(*d, 'a')
    yield *d
  end
  l.start
end

def handle_klass(k)
  klass = site_class(k)
  klass.dirs.each do |dir|
    listen_to(dir) do |*d|
      clean_errors(*d)
      table_update(klass, *d)
    end
  end
end

def handle_assets(assets)
  s = mixin(assets)
  listen_to(s.src) do |u, a, d|
    mixin_changed = false
    if s.respond_to?(:mixins)
      mixin_changed = u.delete(s.mixins) != nil
    else
      clean_errors(u, a, d)
    end
    update_assets(s, u, a, d, mixin_changed)
  end
end

end # module Watch

sync(Watch, false)
sleep
