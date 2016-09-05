require 'asciidoctor'
require 'asciidoctor/extensions'
require_relative 'config'
require_relative 'helpers'
require 'uri'

class FlickContent
  def create_link(target, attrs)
    "https://www.flickr.com/photos/#{target}/player"
  end

  def element
    "iframe"
  end

  def options(attrs)
    ""
  end
end

class VeohContent
  def create_link(target, attrs)
    "http://www.veoh.com/videodetails2.swf"\
      "?permalinkId=#{target}&amp;id=9953844&amp;"\
       "player=videodetailsembedded&amp;videoAutoPlay=0"
  end

  def element
    "embed"
  end

  def options(attrs)
    ""
  end
end

class SwfContent
  def create_link(target, attrs)
    target
  end

  def element
    "embed"
  end

  def options(attrs)
    ""
  end
end

class IframeContent
  def create_link(target, attrs)
    target
  end

  def element
    "iframe"
  end

  def options(attrs)
    ""
  end
end

class YandexMoneyContent
  include CommonHelpers

  def create_link(target, attrs)
    yandex_money_url(target, attrs['title'],
                      attrs['sum'], attrs['redirect'])
  end

  def element
    "iframe"
  end

  def options(attrs)
    %(allowtransparency scrolling="no")
  end
end

class ContentBlockMacro < Asciidoctor::Extensions::BlockMacroProcessor
  use_dsl

  named :content
  name_positional_attributes 'type', 'width', 'height'

  def process(parent, target, attrs)
    klass = attrs['role']
    type = attrs['type']
    fullscreen = 'allowfullscreen webkitallowfullscreen '\
      'mozallowfullscreen oallowfullscreen msallowfullscreen'
    props = {
      'flickr' => FlickContent,
      'veoh' => VeohContent,
      'swf' => SwfContent,
      'iframe' => IframeContent,
      'yandex-money' => YandexMoneyContent
    }[type].new
    html = %(
<div class="objectblock #{type} #{klass}">
  <div class="content">
    <#{props.element} src="#{props.create_link(target, attrs)}"
      width="#{attrs['width']}"
      height="#{attrs['height']}"
      #{props.options(attrs)} frameborder="0" #{fullscreen}>
    </#{props.element}>
  </div>
</div>
    )
    create_pass_block parent, html, attrs, subs: nil
  end
end

Asciidoctor::Extensions.register do
  if document.basebackend? 'html'
    block_macro ContentBlockMacro
  end
end
