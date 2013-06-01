#!/usr/bin/env ruby

require 'kconv'

class HtmlElement

  class Children < Array

    def to_s
      self.join("")
    end
  end

  module CHARSET
    EUC_JP = "EUC-JP"
    SJIS = "Shift_JIS"
    UTF8 = "UTF-8"
    LATIN1 = "ISO-8859-1"
  end

  DOCTYPE = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

  ESC = {
    '&' => '&amp;',
    '"' => '&quot;',
    '<' => '&lt;',
    '>' => '&gt;'
  }

  DECODE = ESC.invert
  CharEntityPat = /#{DECODE.keys.join("|")}/
  

  ELEMENT_TYPES = {
    :BLOCK => %w(html body div table colgroup thead tbody ul ol dl head p pre blockquote style),
    :HEADING_TYPE_BLOCK => %w(dt dd tr title h1 h2 h3 h4 h5 h6),
    :LIST_ITEM_TYPE_BLOCK => %w(li col),
    :EMPTY_BLOCK => %w(img meta link base input hr)
  }
  
  ELEMENTS_FORMAT = {
    :INLINE => "<%s%s>%s</%s>",
    :BLOCK => "<%s%s>#{$/}%s</%s>#{$/}",
    :HEADING_TYPE_BLOCK => "<%s%s>%s</%s>#{$/}",
    :LIST_ITEM_TYPE_BLOCK => "<%s%s>%s#{$/}",
    :EMPTY_BLOCK => "<%s%s>#{$/}"
  }

  def self.assign_tagformats
    tagformats = Hash.new(ELEMENTS_FORMAT[:INLINE])
    ELEMENT_TYPES.each do |type, names|
      names.each {|name| tagformats[name] = self::ELEMENTS_FORMAT[type] }
    end
    tagformats[""] = "%s%s%s"
    tagformats
  end

  TagFormats = self.assign_tagformats

  Html5Tags = %w(article section hgroup aside nav menu header footer menu figure details legend)

  def HtmlElement.escape(str)
    str.gsub(/[&"<>]/on) {|pat| ESC[pat] }
  end

  def HtmlElement.decode(str)
    str.gsub(CharEntityPat) {|ent| DECODE[ent]}
  end

  def initialize(tagname)
    @parent = nil
    @tagname = tagname
    @children = Children.new
    @attributes = {}
    @end_comment_not_added = true
  end

  attr_reader :tagname
  attr_accessor :parent, :children

  def empty?
    @children.empty?
  end

  def push(child)
    @children.push child
    child.parent = self if child.kind_of? HtmlElement
    self
  end

  def pop
    @children.pop
  end

  def []=(attribute, value)
    @attributes[attribute] = value
  end

  def [](attribute)
    @attributes[attribute]
  end
  
  def format_attributes
    @attributes.collect do |attr,value|
      ' %s="%s"'%[attr,HtmlElement.escape(value.to_s)]
    end.sort.join("")
  end
  private :format_attributes

  def add_end_comment_for_div
    if @tagname == "div" and @end_comment_not_added
      id_or_class = self["id"]||self["class"]
      self.push HtmlElement.comment("end of #{id_or_class}") if id_or_class
      @end_comment_not_added = false
    end
  end

  def to_s
    add_end_comment_for_div
    self.class::TagFormats[@tagname]%[@tagname, format_attributes, @children, @tagname]
  end

  def self.doctype(encoding="UTF-8")
    self::DOCTYPE%[encoding]
  end
  alias to_str to_s

  def HtmlElement.comment(content)
    "<!-- #{content} -->#{$/}"
  end

  def configure
    yield self
    self
  end
      
  def self.create(tagname,content=nil)
    if Html5Tags.include? tagname
      tag = self.new("div")
      tag["class"] = tagname
    else
      tag = self.new(tagname)
    end
    tag.push content if content
    yield tag if block_given?
    tag
  end

  def HtmlElement.urlencode(str)
    str.toutf8.gsub(/[^\w\.\-]/n) {|ch| format('%%%02X', ch[0]) }
  end

  def HtmlElement.urldecode(str)
    utf = str.gsub(/%\w\w/) {|ch| [ch[-2,2]].pack('H*') }
    return utf.tosjis if $KCODE =~ /^s/io
    return utf.toeuc if $KCODE =~ /^e/io
    utf
  end
end
  
def Tag(tagname,content=nil)
  HtmlElement.create(tagname,content)
end

class XhtmlElement < HtmlElement

  DOCTYPE = '<?xml version="1.0" encoding="%s"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'.split(/\r?\n/o).join($/)+"#{$/}"

  ELEMENTS_FORMAT = {
    :INLINE => "<%s%s>%s</%s>",
    :BLOCK => "<%s%s>#{$/}%s</%s>#{$/}",
    :HEADING_TYPE_BLOCK => "<%s%s>%s</%s>#{$/}",
    :LIST_ITEM_TYPE_BLOCK => "<%s%s>%s</%s>#{$/}",
    :EMPTY_BLOCK => "<%s%s />#{$/}"
  }

  TagFormats = self.assign_tagformats
end
