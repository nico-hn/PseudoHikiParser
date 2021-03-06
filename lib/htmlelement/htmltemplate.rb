#!/usr/bin/env ruby

require 'htmlelement'

class HtmlTemplate

  META_CHARSET = "text/html; charset=%s"
  LANGUAGE = Hash.new("en")
  LANGUAGE[HtmlElement::CHARSET::EUC_JP] = "ja"
  LANGUAGE[HtmlElement::CHARSET::SJIS] = "ja"
  ELEMENT = { self => HtmlElement }

  def initialize(charset=ELEMENT[self.class]::CHARSET::UTF8, language="en", css_link="default.css", base_uri=nil)
    @html = create_element("html", nil, "lang" => language)
    @head = create_element("head")
    @charset = charset
    @content_language = create_meta("Content-Language", language)
    @base = set_path_to_base(base_uri)
    @content_type = set_charset_in_meta(charset)
    @content_style_type = create_meta("Content-Style-Type", "text/css")
    @content_script_type = create_meta("Content-Script-Type", "text/javascript")
    @default_css_link = create_css_link(css_link)
    @title = nil
    @title_element = create_element("title")
    @body = create_element("body")
    @default_skip_link_labels = {
      "en" => "Skip to Content",
      "ja" => "\u{672c}\u{6587}\u{3078}", # honbun he
      "fr" => "Aller au contenu"
    }
    @html.push @head
    @html.push @body
    [ @content_language,
      @content_type,
      @content_sytle_type,
      @content_script_type,
      @title_element,
      @base,
      @default_css_link
    ].each do |element|
      @head.push element
    end
  end
  attr_reader :title, :head, :body

  def create_element(*params)
    ELEMENT[self.class].create(*params)
  end

  def charset=(charset_name)
    @charset=charset_name
    @content_language["content"] = LANGUAGE[@charset]
    @content_type["content"] = META_CHARSET%[charset_name]
  end

  def language=(language)
    @content_language["content"] = language
    @html["lang"] = language
  end

  def base=(base_uri)
    if @base.empty?
      @base = create_element("base", nil, "href" => base_uri)
      @head.push @base
    else
      @base["href"] = base_uri
    end
  end

  def add_css_file(file_path)
    @head.push create_css_link(file_path)
  end

  def default_css=(file_path)
    @default_css_link["href"] = file_path
  end

  def embed_style(css)
    style = create_element("style", nil, "type" => "text/css")
    @head.push style
    style.push format_css(css)
  end

  def title=(title)
    @title_element.pop until @title_element.empty?
    @title = title
    @title_element.push title
  end

  def push(element)
    @body.push element
  end

  def euc_jp!
    self.charset = ELEMENT[self.class]::CHARSET::EUC_JP
    self.language = "ja"
  end

  def sjis!
    self.charset = ELEMENT[self.class]::CHARSET::SJIS
    self.language = "ja"
  end

  def utf8!
    self.charset = ELEMENT[self.class]::CHARSET::UTF8
  end

  def latin1!
    self.charset = ELEMENT[self.class]::CHARSET::LATIN1
  end

  def to_s
    [ELEMENT[self.class].doctype(@charset),
      @html].join("")
  end

  def add_skip_link(to="contents", from=@body,label=default_skip_link_label)
    skip_link_container(from).unshift create_element("a", label, "href" => "##{to}")
  end

  private

  def create_meta(type, content)
    create_element("meta", nil,
                   "http-equiv" => type,
                   "content" => content)
  end

  def create_css_link(file_path)
    create_element("link", nil,
                   "rel" => "stylesheet",
                   "type" => "text/css",
                   "href" => file_path)
  end

  def set_charset_in_meta(charset)
    create_meta("Content-Type", META_CHARSET%[charset])
  end

  def set_path_to_base(base_uri)
    return "" unless base_uri
    create_element("base", nil, "href" => base_uri)
  end

  def format_css(css)
    ["<!--", css.rstrip, "-->", ""].join($/)
  end

  def skip_link_container(from)
    return from unless from == @body
    create_element("div").tap do |div|
      div["class"] = "skip-link"
      @body.unshift div
    end
  end

  def default_skip_link_label
    @default_skip_link_labels[@html["lang"]] ||
      @default_skip_link_labels["en"]
  end
end

class XhtmlTemplate < HtmlTemplate
  ELEMENT[self] = XhtmlElement

  def initialize(*params)
    super(*params)
    @html['xmlns'] = 'http://www.w3.org/1999/xhtml'
    @html["xml:lang"] =  @html["lang"] #language
  end

  def language=(language)
    super(language)
    @html["xml:lang"] = language
  end

  private

  def format_css(css)
    css.rstrip + $/
  end
end

class Xhtml5Template < XhtmlTemplate
  ELEMENT[self] = Xhtml5Element

  def initialize(*params)
    super(*params)

    def @content_language.to_str
      ""
    end

    def @content_script_type.to_str
      ""
    end
  end

  def set_charset_in_meta(charset)
    create_element("meta", nil, "charset" => charset)
  end

  def charset=(charset_name)
    @charset=charset_name
    @content_type["charset"] = @charset
  end
end
