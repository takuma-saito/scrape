# coding: utf-8
# html を解析するスクリプト

require_relative("debug")

class Scrape
  include Debug
  attr_accessor :root

  def initialize(html)
    @tree = Tree.new(html)
    @root = @tree.root
  end

  # Tree クラスへのプロキシパターン
  # メソッドがない場合 Tree クラスに問い合わせる
  def method_missing(method, *args, &block)
    methods = Tree.instance_methods
    if methods.include? method
      @tree.send method.to_sym, *args, &block
    else
      super
    end
  end

  class Tree
    include Debug
    attr_reader :root

    # 終了タグがないHTMLタグ
    EXCEPT_TAGS = 
      ["input", "meta", "hr", "br", "link", "img"]

    # HTMLタグ一覧
    HTML_TAGS = 
      ["a", "applet", "b", "base", "big", "blockquote", "body",
       "br", "caption", "dd", "div", "dl", "dt", "em", "embed",
       "font", "form", "h", "head", "hr", "html", "i", "img", "input",
       "li", "link", "meta", "nobr", "noembed", "object", "p", "pre",
       "s", "script", "select", "small", "span", "strike", "strong",
       "sub", "sup", "table", "tbody", "td", "textarea", "tfoot", "th",
       "thead", "title", "tr", "tt", "u", "ul", "!DOCTYPE", "address",
       "center"]

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
        when :tag_end
          if @prev_type == :tag_start
            @self.set_tag_end(@pos)
            # 閉じるタグがない場合
            if EXCEPT_TAGS.include? @self.name || type == :tag_close
              tag = @stack.pop
              tag.set_pos_end(@pos)
            end
          end
        when :end
          tag = @stack.pop
          tag.set_pos_end(@pos)
        when :comment_start
        when :comment_end
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
      when @html[@pos, 2] == "</"
        type = :end
      when @html[@pos, 2] == "/>"
        type = :tag_close
      when @html[@pos] == "<"
        type = :tag_start
      when @html[@pos] == ">"
        type = :tag_end
      end
      # コメントアウトの処理
      # unless (@prev_type == :comment_start) && (type == :comment_end)
      #   type = :comment_start
      # end
      type
    end

    def show(tree = @root)
      tree.children.each do |sub_tree|
        sub_tree.show
        show(sub_tree) unless sub_tree.children.empty?
      end
    end

    def parse(args = {}, &block)
      domain = Domain.new(args, &block)
      target = @root.access domain.dup.struct
      raise "Can't retrieve HTML element" unless target
      target
    end

    def parse_all(&block)
      domain = Domain.new(&block)
      target = @root.access_all domain.dup.struct
      raise "Can't retrieve HTML element" if target.empty?
      target
    end

    def access(args = {}, &block)
      args[:sp] = (args.include? :sp) ? args[:sp] : "/"
      domain = Domain.new(args, &block)
      obj = @root
      domain.each do |dom|
        obj = obj.send dom[:name].to_sym
        if dom[:number] > 0
          obj = obj.send "[]".to_sym, dom[:number]
        end
      end
      obj
    end

    
    ##########################################################
    # ドメインクラス                                         #
    #  - スクレイプ時に利用する DOM オブジェクトを表す構造体 #
    ##########################################################    

    class Domain
      attr_reader :struct

      # 初期化
      def initialize(args = {}, &block)
        @sp = (args.include? :sp) ? args[:sp] : " "
        @struct = []
        @text = block.call
        set_struct
      end
      
      # textデータをデータ構造に変換
      def set_struct
        raise "Scrape.parse block must be String: #{@text}" unless @text.kind_of? String
        struct = @text.split(@sp)
        struct.delete ">" && ""
        struct.each do |dom|
          id = get_id(dom.dup)
          cls = get_class(dom.dup)
          tag = get_tag(dom.dup)
          number = get_number(dom.dup)
          unless tag.empty?
            raise "unkown tag: #{tag}" unless HTML_TAGS.include? tag
          end
          @struct << {:class => cls, :id => id, :name => tag, :number => number}
        end
      end

      def each
        @struct.each do |st|
          yield st
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

      # number が存在するかを確認
      def exist_number?(string)
        return true if string.match(/\[([0-9]*?)\]/)
      end

      # classを削除
      def remove_class(dom)
        dom.gsub!(/(#.*+)/, "")
      end

      # idを削除
      def remove_id(dom)
        dom.gsub!(/(\..*+)/, "")
      end

      # number を削除
      def remove_number(dom)
        dom.gsub!(/\[([\d*?])\]/, "")
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
        remove_number dom if exist_number? dom
        dom
      end

      # 数字を取得する
      def get_number(dom)
        if match = /[([0-9]*?)]/.match(dom)
          match[0].to_i
        else
          0
        end
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

      def [](idx)
        name = self.name
        elems = @parent.children.select do |child|
          child.name == name
        end
        elems[idx - 1]
      end

      # 子要素の名前を出力
      def list
        tag = @children.map do |sub_tree|
          {:name => sub_tree.tag.name, :property => sub_tree.tag.property, :children => sub_tree.children}
        end
        out = tag.map do |t|
          out = String.new
          out << "#{t[:name]}"
          t[:property].each do |p|
            key = "", value = "", name = ""
            p.each do |k, v| 
              key = k.to_s; value = v.to_s
            end
            name = "." if p[0] === :class
            name = "#" if p[0] === :id
            if value.include?(" ")
              value = value.split(" ").join(", ")
              value = "[#{value}]"
            end
            out << "#{name}"
            out << "#{value}" unless name.empty? # id, class が登録されている場合のみ表示
          end
          out << " >> " unless t[:children].empty?
          out
        end
        out.join("  ")
      end
      
      # プロパティ, 名前, タグで子要素を検索する
      def search(dom)
        return false if self.children.empty?
        self.children.each do |sub_tree|
          return sub_tree if sub_tree.tag.is_valid?(dom)
          result = sub_tree.search(dom)
          return result if result
        end
        false
      end

      # 合致する プロパティ, 名前, タグ の子要素を全て検索する
      def search_all(dom)
        return [] if self.children.empty?
        out = []
        self.children.each do |sub_tree|
          out << sub_tree if sub_tree.tag.is_valid?(dom)
          result = sub_tree.search_all(dom)
          out += result unless result.empty?
        end
        out
      end

      def access(domain, tree = self)
        return tree if domain.empty?
        dom = domain.shift        
        if (sub_tree = tree.search(dom))
          result = access(domain, sub_tree)
          return result if result
        end
        false
      end

      def access_all(domain, tree = self)
        return tree if domain.empty?
        dom = domain.shift
        if domain.empty?
          if (sub_tree = tree.search_all(dom))
            return sub_tree
          end
        else
          if (sub_tree = tree.search(dom))
            result = access_all(domain, sub_tree)
            return result if result
          end
        end
        false
      end

      # 子要素へアクセス
      def method_missing(method, *args, &block)
        tree = @children.find do |sub_tree| 
          sub_tree.tag.name == method.to_s
        end
        
        # メソッドがない場合は @tag へメソッドを送る
        if tree.nil?
          super unless @tag.methods.include? method.to_sym
          @tag.send method, *args, &block
        else
          tree
        end
      end

    end

    
    
    #####################################
    # スタッククラス                    #
    #   - html 解析時に使用するスタック #
    #####################################
    
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
      attr_reader :name, :property, :content

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
        puts "name = #{@name},   property = #{@property},   pos_start = #{@pos_start},   pos_end = #{@pos_end},   content = #{@content}"
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
          @property = matches.map {|match| {match[0].to_sym => match[1]} }
        end
      end

      # プロパティからシンボルに対応する要素を取得する
      def property_select(sym)
        value = @property.select do |p|
          p.include? sym
        end
        unless value.empty?
          value = value[0][sym]
          # 空白がある場合, 分割する
          if value.include? " "
            value = value.split(" ")
          end
        else
          value = nil
        end
        value
      end

      # 構造化されたプロパティを取得する
      def property_get
        my_id = property_select(:id)
        my_class = property_select(:class)
        [@name, my_id, my_class]
      end

      # プロパティ同士を比較する
      def prop_compare(my_property, property)
        flg = true
        3.times do |i|
          next if property[i] == :skip
          if my_property[i].instance_of? Array
            res = my_property[i].find do |sub_prop|
              sub_prop == property[i]
            end
            if res.empty?
              flg = false; break
            end
          else
            unless my_property[i] == property[i]
              flg = false; break
            end
          end
        end
        return flg
      end

      # id, cls, tag_name, がそれぞれ一致する場合のみ true を返す
      # :skip の場合は比較しない
      def is_valid?(dom)
        dom[:name] = :skip if dom[:name].empty?
        dom[:id] =  :skip if dom[:id].nil?
        dom[:class] = :skip if dom[:class].nil?
        property = [dom[:name], dom[:id], dom[:class]]
        my_property = property_get
        prop_compare my_property, property
      end

      def set_tag_start(pos)
        @tag_start = pos
      end
    end
  end
end
