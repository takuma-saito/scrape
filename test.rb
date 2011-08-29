# coding: utf-8
require_relative("class_extend")
require_relative("scrape")

# スクレイピングを行う
html = "sample.html"
text = html.get_file
target = Scrape.parse text do 
  "html.wrapper > #html > p.sub"
end


