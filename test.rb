# coding: utf-8
require_relative("class_extend")
require_relative("scrape")

# スクレイピングを行う
data = "html/index.html"
text = data.get_file

# スクレイピングを行う
scrape = Scrape.new(text)

# scrape.show
puts scrape.root.html.body.div.center.div[3].content

# target = scrape.access do 
#   # div[7] がおかしい
#   "/html/body/div/center/div[7]/div/div[2]/table/tr/td/table/tr/td[2]"
# end

# target.show
