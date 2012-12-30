#/usr/bin/env ruby

require 'treestack'
require 'htmlelement'

module PseudoHiki

  class BlockParser
    URI_RE = /(?:(?:https?|ftp|file):|mailto:)[A-Za-z0-9;\/?:@&=+$,\-_.!~*\'()#%]+/ #borrowed from hikidoc

    module LINE_PAT
      VERBATIM_BEGIN = /\A(<<<\s*)/o
      VERBATIM_END = /\A(>>>\s*)/o
      PLUGIN_BEGIN = /\{\{/o
      PLUGIN_END = /\}\}/o
    end

    ParentNode = {}

    HeadToLeaf = {}

    attr_reader :stack

    class BlockStack < TreeStack; end

    class BlockNode < BlockStack::Node
      attr_accessor :base_level, :relative_level_from_base

      def nominal_level
        return nil unless first
        first.nominal_level
      end

      def push_self(stack)
        @stack = stack
        super(stack)
      end

      def breakable?(breaker)
        not (kind_of?(breaker.block) and nominal_level == breaker.nominal_level)
      end
    end

    class BlockLeaf < BlockStack::Leaf
      @@head_re = {}
      attr_accessor :nominal_level

      def self.head_re=(head_regex)
        @@head_re[self] = head_regex
      end

      def self.head_re
        @@head_re[self]
      end

      def self.with_depth?
        false
      end

      def self.create(line)
        line.sub!(self.head_re,"") if self.head_re
        self.new.push line
      end

      def self.assign_head_re(head, need_to_escape=true, reg_pat="(%s)")
        head = Regexp.escape(head) if need_to_escape
        self.head_re = Regexp.new('\\A'+reg_pat%[head])
      end

      def head_re
        @@head_re[self.class]
      end

      def block
        ParentNode[self.class]
      end

      def push_block(stack)
        stack.push(block.new)
      end

      def under_appropriate_block?(stack)
        stack.current_node.kind_of? block and stack.current_node.nominal_level == nominal_level
      end

      def push_self(stack)
        push_block(stack) unless under_appropriate_block?(stack)
        super(stack)
      end
    end

    class NestedBlockNode < BlockNode; end
      
    class ListTypeBlockNode < NestedBlockNode
      def breakable?(breaker)
        return false if breaker.block.superclass == ListTypeBlockNode and nominal_level <= breaker.nominal_level
        true
      end
    end

    class NestedBlockLeaf < BlockLeaf
      def self.assign_head_re(head, need_to_escape)
        super(head, need_to_escape, "(%s)+")
      end

      def self.create(line)
        m = self.head_re.match(line)
        leaf = super(line)
        leaf.nominal_level = m[0].length
        leaf
      end

      def self.with_depth?
        true
      end
    end

    module BlockElement
      class DescLeaf < BlockLeaf; end
      class VerbatimLeaf < BlockLeaf; end
      class QuoteLeaf < BlockLeaf; end
      class TableLeaf < BlockLeaf; end
      class CommentOutLeaf < BlockLeaf; end
      class HeadingLeaf < NestedBlockLeaf; end
      class ParagraphLeaf < BlockLeaf; end
      class HrLeaf < BlockLeaf; end
      class BlockNodeEnd < BlockLeaf; end

      class ListLeaf < NestedBlockLeaf; end
      class EnumLeaf < NestedBlockLeaf; end

      class DescNode < BlockNode; end
      class VerbatimNode < BlockNode; end
      class QuoteNode < BlockNode; end
      class TableNode < BlockNode; end
      class CommentOutNode < BlockNode; end
      class HeadingNode < NestedBlockNode; end
      class ParagraphNode < BlockNode; end
      class HrNode < BlockNode; end

      class ListNode < ListTypeBlockNode; end
      class EnumNode < ListTypeBlockNode; end
    end
    include BlockElement

    class BlockElement::BlockNodeEnd
      def push_self(stack); end
    end

#    class HeadingNode
    class BlockElement::HeadingNode
      def breakable?(breaker)
        kind_of?(breaker.block) and nominal_level >= breaker.nominal_level
      end
    end

    [[DescLeaf, DescNode],
     [VerbatimLeaf, VerbatimNode],
     [QuoteLeaf, QuoteNode],
     [TableLeaf, TableNode],
     [CommentOutLeaf, CommentOutNode],
     [HeadingLeaf, HeadingNode],
     [ParagraphLeaf, ParagraphNode],
     [HrLeaf, HrNode],
     [ListLeaf, ListNode],
     [EnumLeaf, EnumNode]
    ].each do |leaf, node|
      ParentNode[leaf] = node
    end

    ParentNode[BlockNodeEnd] = BlockNodeEnd

    def self.assign_head_re
      space = '\s'
      head_pats = []
      [[':', DescLeaf],
       [space, VerbatimLeaf],
       ['""', QuoteLeaf],
       ['||', TableLeaf],
       ['//', CommentOutLeaf],
       ['!', HeadingLeaf],
       ['*', ListLeaf],
       ['#', EnumLeaf]
      ].each do |head, leaf|
        HeadToLeaf[head] = leaf
        escaped_head = head != space ? Regexp.escape(head) : head
        head_pat = leaf.with_depth? ? "(#{escaped_head})+" : "(#{escaped_head})"
        head_pats.push head_pat
        leaf.head_re = Regexp.new('\\A'+head_pat)
      end
      HrLeaf.head_re = Regexp.new(/\A(----)\s*$/o)
      BlockNodeEnd.head_re = Regexp.new(/^(\r?\n?)$/o)
      Regexp.new('\\A('+head_pats.join('|')+')')
    end
    HEAD_RE = assign_head_re

    def initialize
      root_node = BlockNode.new
      def root_node.breakable?(breaker)
        false
      end
      @stack = BlockStack.new(root_node)
    end

    def breakable?(breaker)
      @stack.current_node.breakable?(breaker)
    end

    def tagfy_link(line)
      line.gsub(URI_RE) do |url|
        unless ($`)[-2,2] == "[[" or ($`)[-1,1] == "|"
          "[[#{url}]]"
        else
          url
        end
      end
    end

    def select_leaf_type(line)
      [BlockNodeEnd, HrLeaf].each {|leaf| return leaf if leaf.head_re =~ line }
      matched = HEAD_RE.match(line)
      return HeadToLeaf[matched[0]]||HeadToLeaf[line[0,1]] || HeadToLeaf['\s'] if matched
      ParagraphLeaf
    end

    def add_verbatim_block(lines)
      until lines.empty? or LINE_PAT::VERBATIM_END =~ lines.first
        @stack.push(VerbatimLeaf.create(lines.shift))
      end
    end

    def add_leaf(line)
      leaf = select_leaf_type(line).create(line)
      while breakable?(leaf)
        @stack.pop
      end
      @stack.push leaf
    end

    def read_lines(lines)
      while line = lines.shift
        if LINE_PAT::VERBATIM_BEGIN =~ line
          add_verbatim_block(lines)
        else
          add_leaf(line)
        end
      end
    end

    def self.parse(lines)
      parser = self.new
      parser.read_lines(lines)
      parser.stack.tree
    end
  end
end
