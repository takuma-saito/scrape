
# getter, setter を設定するMixin モジュール

module Debug

  # オブジェクトのインスタンス変数をダンプする
  def attr_dump (*opts)
    args = opts[0]
    delete = args.nil? ? [] : args[:delete]
    puts "#{self.class}:"
    self.instance_variables.each do |key|
      value = instance_variable_get("#{key}")
      print "#{key} = #{value}\n" unless delete.include? key[1..(key.size - 1)].to_sym
    end
    print "\n"
  end

  def monitor(obj)
    name = obj.to_s if (obj.respond_to? :to_s)
    Monitor.new(obj, name)
  end

  class Monitor
    # メソッドを削除
    instance_methods.each do |method|
      method = method.to_sym
      next if method == :object_id || method == :__id__ || method == :__send__
      undef_method method
    end

    # 初期化
    def initialize(obj, name = "", out = STDERR)
      @obj = obj
      @name = name
      @out = out
    end

    # メソッドのトレースを行う
    def method_missing(method, *args, &block)
      begin
        arglist = args.map {|arg| arg.inspect }.join(', ')
        @out << "start ... #{@name}.#{method} #{caller[0]}\n"
        res = @obj.send method, *args, &block
        @out << "exit  ... #{@name}.#{method} #{caller[0]}\n"
        res
      rescue      
        @out << "raise ... #{@name}.#{method} #{caller[0]}\n"
        raise
      end
    end
  end

  class << self

    # クラス拡張
    def included(base)
      base.extend ClassMethods
    end

    # 終了時にプロファイルを表示
    def hook_exit
      at_exit do
        show_profile
      end
    end

    # プロファイルの時間を降順に設定する
    def set_profile_time_desc
      @methods.each do |class_one, methods|
        methods.sort! {|m1, m2| m2[:time] <=> m1[:time] }
      end
    end

    # プロファイルを表示する
    def show_profile
      set_profile_time_desc
      @methods.each do |class_one, methods|
        print "#{class_one}:\n"
        print "%-17s  %-10s %-16s\n" % ["[name]", "[count]", "[time]"]
        methods.each do |method|
          print "%-17s  %-6d %11.5f\n" % [method[:name], method[:count], method[:time]]
        end
        print "\n"
      end
    end

    # クラスを登録して全てのメソッドを監視する
    def profile(*classes)
      methods_init classes
      hook_exit
      @classes = classes
      @classes.each do |class_one|
        methods = @methods[class_one]
        class_one.instance_eval do
          methods.each do |method|
            name = method[:name]
            alias_method "#{name}_origin", "#{name}"
            define_method "#{name}" do |*value, &block|
              time_start = Time.now.to_f
              method[:count] += 1
              result = method(:"#{name}_origin").call(*value, &block)
              method[:time] += Time.now.to_f - time_start
              result
            end
          end
        end
      end
    end

    # 監視する各オブジェクトのメソッドを登録・初期化
    def methods_init (classes)
      @methods = {}
      classes.each do |class_one|
        @methods[class_one] = []
        class_one.instance_methods(false).each do |method|
          @methods[class_one] << {:name => method.to_s, :count => 0, :time => 0 }
        end
      end
    end
  end

  module ClassMethods

    # インスタンス変数を定義する
    def attr_set (*attributes)
      attributes.each do |attribute|
        define_method "#{attribute}=" do |value|
          instance_variable_set("@#{attribute}", value)
        end
      end
    end

    # インスタンス変数を設定する
    def attr_get (*attributes)
      attributes.each do |attribute|
        define_method "#{attribute}" do
          instance_variable_get("@#{attribute}")
        end
      end
    end

    # インスタンス変数を設定, 定義する
    def attr_getset (*attributes)
      attr_set(*attributes)
      attr_get(*attributes)
    end

    # 対称性
    alias attr_setget attr_getset
  end
end
