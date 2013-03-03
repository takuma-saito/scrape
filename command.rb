# coding: utf-8

require_relative("interface")

raise "Please input file name" if ARGV.empty?

EXIT_CMD = ["exit", "quit", "q"]

# スクレイピングを行う
html = ARGV.shift
text = html.get_file
interface = ScrapeInterface.new(text)

# コマンドの解析を行う
loop do
  print "sp > "
  (line = gets).chomp!
  break if EXIT_CMD.include? line
  cmd, arg = line.split(" ")
  next if cmd.nil?
  cmd = cmd.to_sym
  if  interface.methods.include?(cmd)
    begin
      (arg.nil?) ? interface.send(cmd) : interface.send(cmd, arg)
    rescue StandardError => error
      puts "#{error.class}: #{error.message}"
      next
    end
  else
    puts "Unkown Command: #{line}"
  end
end

puts "bye"
