require 'asciidoctor'
require 'asciidoctor/extensions'

class FlickContent
  def create_link(target)
    "https://www.flickr.com/photos/#{target}/player"
  end

  def element
    "iframe"
  end
end

class VeohContent
  def create_link(target)
    "http://www.veoh.com/videodetails2.swf"\
      "?permalinkId=#{target}&amp;id=9953844&amp;"\
       "player=videodetailsembedded&amp;videoAutoPlay=0"
  end

  def element
    "embed"
  end
end

class SwfContent
  def create_link(target)
    target
  end
  def element
    "embed"
  end
end

class IframeContent
  def create_link(target)
    target
  end
  def element
    "iframe"
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
      'iframe' => IframeContent
    }[type].new
    html = %(
<div class="objectblock #{type} #{klass}">
  <div class="content">
    <#{props.element} src="#{props.create_link(target)}"
            width="#{attrs['width']}"
            height="#{attrs['height']}"
	    frameborder="0" #{fullscreen}>
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
