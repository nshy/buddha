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

def handle_resource(resource)
  resource.dirs.each do |dir|
    listen_to(dir) do |*d|
      clean_errors(*d)
      table_update(resource, *d)
    end
  end
end

def handle_assets(assets)
  listen_to(assets.src) do |u, a, d|
    mixin_changed = false
    if assets.respond_to?(:mixins)
      mixin_changed = u.delete(assets.mixins) != nil
    else
      clean_errors(u, a, d)
    end
    update_assets(assets, u, a, d, mixin_changed)
  end
end

end # module Watch

sync(Watch, false)
sleep
