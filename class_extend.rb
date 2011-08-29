
# 既存のクラスに対する拡張を入れる

class String
  # 文字列 ⇒ クラスへ変更
  def get_class
    Kernel.const_get(self)
  end

  # ファイルを取得する
  def get_file
    raise IOError unless File.exist? self
    enc_from = `nkf -g #{self}`.chomp!.downcase # wrong
    File.open(self, "r") do |f|
      f.set_encoding(enc_from, Encoding::UTF_8)
      f.read
    end
  end

end

class Array
  # 配列 ⇒ 文字列 へ変更
  def to_string
    self.map {|a| a.inspcet }.join(', ')
  end
end
