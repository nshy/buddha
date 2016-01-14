require 'asciidoctor'
require 'asciidoctor/extensions'

class FlickrBlockMacro < Asciidoctor::Extensions::BlockMacroProcessor
  use_dsl

  named :flickr

  def process(parent, target, attrs)
    klass = attrs['role']
    html = %(
<div class="objectblock flickr #{klass}">
  <div class="content">
    <iframe src="https://www.flickr.com/photos/#{target}/player"
           frameborder="0" allowfullscreen webkitallowfullscreen
           mozallowfullscreen oallowfullscreen msallowfullscreen>
    </iframe>
  </div>
</div>
    )
    create_pass_block parent, html, attrs, subs: nil
  end
end

class VeohBlockMacro < Asciidoctor::Extensions::BlockMacroProcessor
  use_dsl

  named :veoh

  def process(parent, target, attrs)
    klass = attrs['role']
    id = "#{target}&amp;"\
         "id=9953844&amp;"\
         "player=videodetailsembedded&amp;"\
         "videoAutoPlay=0"
    html = %(
<div class='objectblock veoh #{klass}'>
  <div class="content">
    <embed src="http://www.veoh.com/videodetails2.swf?permalinkId=#{id}"
           allowfullscreen="true"
           width="540" height="438"
           bgcolor="#FFFFFF"
           type="application/x-shockwave-flash"
           pluginspage="http://www.macromedia.com/go/getflashplayer">
    </embed>
  </div>
</div>
    )
    create_pass_block parent, html, attrs, subs: nil
  end
end

class SwfBlockMacro < Asciidoctor::Extensions::BlockMacroProcessor
  use_dsl

  named :swf
  name_positional_attributes 'width', 'height'

  def process(parent, target, attrs)
    klass = attrs['role']
    html = %(
<div class="objectblock swf #{klass}">
  <div class="content">
    <embed src="#{target}"
           width="#{attrs['width']}"
           height="#{attrs['height']}"/>
  </div>
</div>
    )
    create_pass_block parent, html, attrs, subs: nil
  end
end

Asciidoctor::Extensions.register do
  if document.basebackend? 'html'
    block_macro FlickrBlockMacro
    block_macro VeohBlockMacro
    block_macro SwfBlockMacro
  end
end
