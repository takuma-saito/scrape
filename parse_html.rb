# coding: utf-8
# html を解析するスクリプト

require_relative("debug")

class HtmlParse
  include Debug
  attr_accessor :root

  # 終了タグがないhtml要素
  EXCEPT_TAGS = 
    ["input", "meta", "hr", "br", "link"]

  def initialize(html)
    @tree = Tree.new(html)
    result = @tree.access do 
      "html > table"
    end
    p result
  end

  class Tree
    include Debug
    attr_accessor :root

    def initialize(html)
      @pos = 0
      @stack = Stack.new
      @html = html
      Tag.html = html
      eval
      @root = @stack.tree
    end

    def eval_loop
      loop do
        return if eval_end?
        yield
        @pos += 1
      end
    end

    # 解析木を生成する
    def eval
      eval_loop do 
        type = get_type
        case type
        when :tag_start
          tag = Tag.new
          tag.set_tag_start(@pos)
          @stack.push tag
          @self = @stack.last
          # @self.set_tag_start(@pos)
        when :tag_end
          if @prev_type == :tag_start
            @self.set_tag_end(@pos)
            # 閉じるタグがない場合
            if EXCEPT_TAGS.include? @self.name
              tag = @stack.pop
              tag.set_pos_end(@pos)
            end
          end
        when :end
          tag = @stack.pop
          tag.set_pos_end(@pos)
        else
          next
        end
        @prev_type = type
      end
    end

    def eval_end?
      @pos >= (@html.size - 1)
    end

    def get_type
      case
      when @html[@pos, 4] == "<!--"
        type = :comment_start
      when @html[@pos, 4] == "--!>"
        type = :comment_end
      when @html[@pos, 2] == "<!"
        type = :doc_type
      when  @html[@pos, 2] == "</"
        type = :end
      when @html[@pos] == "<"
        type = :tag_start
      when @html[@pos] == ">"
        type = :tag_end
      end
    end

    def show(tree = @root)
      tree.children.each do |sub_tree|
        sub_tree.show
        show(sub_tree) unless sub_tree.children.empty?
      end
    end

    def access(&block)
      domain = Domain.new(&block)
      @root.access domain.dup.struct
    end

    
    ##########################################################
    # ドメインクラス                                         #
    #  - スクレイプ時に利用する DOM オブジェクトを表す構造体 #
    ##########################################################    

    class Domain
      attr_reader :struct

      HTML_TAGS = \
      ["a", "applet", "b", "base", "big", "blockquote", "body",
       "br", "caption", "dd", "div", "dl", "dt", "em", "embed",
       "font", "form", "h", "head", "hr", "html", "i", "img", "input",
       "li", "link", "meta", "nobr", "noembed", "object", "p", "pre",
       "s", "script", "select", "small", "span", "strike", "strong",
       "sub", "sup", "table", "tbody", "td", "textarea", "tfoot", "th",
       "thead", "title", "tr", "tt", "u", "ul", "!DOCTYPE"]

      # 初期化
      def initialize(&block)
        @struct = []
        @text = block.call
        set_struct
      end
      
      # textデータをデータ構造に変換
      def set_struct
        raise "Scrape.parse block must be String: #{@text}" unless @text.kind_of? String
        struct = @text.split(' ')
        struct.delete ">"
        struct.each do |dom|
          id = get_id(dom.dup)
          cls = get_class(dom.dup)
          tag = get_tag(dom.dup)
          unless tag.empty?
            raise "unkown tag: #{tag}" unless HTML_TAGS.include? tag
          end
          @struct << {:class => cls, :id => id, :tag => tag}
        end
      end

      # id が存在するか確認
      def exist_id?(string)
        return true if string.match(/\./)
        false
      end

      # class が存在するか確認
      def exist_class?(string)
        return true if string.match(/#/)
        false
      end

      # classを削除
      def remove_class(dom)
        dom.gsub!(/(#.*+)/, "")
      end

      # idを削除
      def remove_id(dom)
        dom.gsub!(/(\..*+)/, "")
      end

      # クラスを取得する
      def get_class(dom)
        cls = dom.split('#')[1]
        return nil if cls.nil?
        remove_id cls if exist_id? cls
        cls
      end

      # idを取得する
      def get_id(dom)
        id = dom.split('.')[1]
        return nil if id.nil?
        remove_class id if exist_class? id
        id
      end

      # 普通の要素を取得する
      def get_tag(dom)
        remove_class dom if exist_class? dom
        remove_id dom if exist_id? dom
        dom
      end
    end

    ###########################################
    # ノードクラス                            #
    # html 解析木を構成するノード             #
    ###########################################

    class Node
      attr_accessor :children, :parent, :tag
      def initialize(tag = nil, parent = nil)
        @children = []
        @parent = parent
        @tag = tag
      end

      def show
        @tag.show
      end

      # 子要素の名前を出力
      def list
        tag = @children.map do |sub_tree|
          {:name => sub_tree.tag.name, :property => sub_tree.tag.property}
        end
        out = tag.map do |t|
          out = String.new
          out << "#{t[:name]}"
          t[:property].each do |p|
            elem = p[1]
            name = "." if p[0] === :class
            name = "#" if p[0] === :id
            if elem.include?(" ")
              elem = elem.split(" ").join(", ")
              elem = "[#{elem}]"
            end
            out << "#{name}#{elem}"
          end
          out
        end
        puts out.join(" ")
      end

      # 子要素へアクセス
      def method_missing(method)
        tree = @children.find do |sub_tree| 
          sub_tree.tag.name === method.to_s
        end
      end
      
      # プロパティ, 名前, タグで子要素を検索する
      def search(tag_name, id = nil, cls = nil, tree = self)
        return false if tree.children.empty?
        tree.children.each do |sub_tree|
          return sub_tree if (sub_tree.tag.name === tag_name)
          return result if (result = search(tag_name, id, cls, sub_tree))
        end
        false
      end

      def access(domain, tree = self)
        return tree if domain.empty?
        d = domain.shift
        @children.each do  |child|
          if (sub_tree = child.search(d[:tag], d[:class], d[:id], tree))
            p sub_tree.tag.name
            result = access(domain, sub_tree)
            return result if (result)
          end
        end
        false
      end
    end

    
    ###################################
    # スタッククラス                  #
    # - html 解析時に使用するスタック #
    ###################################    

    class Stack
      attr_accessor :tree

      def initialize
        @tree = Node.new
        @curr = @tree
        @stack = []
      end

      def push(tag)
        node = Node.new(tag, @curr)
        @stack.push node
        @curr.children << node
        @curr = @curr.children[-1]
      end

      def pop
        raise "Stack Empty" if @stack.empty?
        @curr = @curr.parent
        node = @stack.pop
        node.tag
      end

      def last
        @curr.tag
      end
    end

    
    
    ##############################
    # タグクラス                 #
    # タグ情報を抽象化したクラス #
    ##############################    

    class Tag
      attr_reader :name, :property

      class << self
        attr_accessor :html
      end

      def initialize
        @pos_start = 0
        @pos_end = 0
        @pos_start = 0
        @tag_start = 0
        @name = ""
        @property = []
      end

      def show
        puts "name = #{@name}, property = #{@property} pos_start = #{@pos_start}, pos_end = #{@pos_end}, content = #{@content}"
      end

      def set_pos_end(pos)
        @pos_end = pos + 1
        @content = Tag.html[@pos_start...@pos_end]
        if @content.nil?
          @content = ""
        else
          @content = @content.chop
        end
      end

      def set_tag_end(pos)
        tag = Tag.html[(@tag_start + 1)...pos]
        set_tag tag
        @pos_start =  @pos_end = pos + 1
      end

      def set_tag(tag)
        name = tag.match(/^(.*?) (.*+)$/)
        unless name.nil?
          @name = name[1]
        else
          @name = tag
        end
        @name.downcase!

        unless (matches = tag.scan( /(\S*?)="(.*?)"/)).empty?
          @property = matches.map {|match| [match[0].to_sym, match[1]] }
        end
      end

      def set_tag_start(pos)
        @tag_start = pos
      end
    end
  end
end

# ファイルを読み込む
html = File.open("html/sample2.html", "r") do |file| 
  #file.set_encoding(Encoding::EUC_JP, Encoding::UTF_8)
  text = file.read
end

html = HtmlParse.new(html)

