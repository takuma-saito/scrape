# coding: utf-8
# スクレイピング用のコマンドラインインターフェイス

require_relative("class_extend")
require_relative("scrape")

class ScrapeInterface
  
  def initialize(text)
    @scrape = Scrape.new(text)
    @node = @scrape.root
  end

  class << self
    # 委譲する
    def proxy_node(*names)
      names.each do |name|
        define_method(name) do 
          self.instance_eval do 
            puts @node.send name
          end
        end
      end
    end
  end
  
  # @node インスタンスに操作を委譲する
  proxy_node :ls, :pwd, :info, :cat

  def show
    @scrape.show
  end

  # ノード間の移動
  def cd(arg)
    if arg == ".." || arg == "../"
      @node = @node.parent
    else
      @node = @scrape.access({}, @node) { arg }
    end
  end

end
