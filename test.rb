# coding: utf-8
require_relative("class_extend")
require_relative("scrape")

# スクレイピングを行う
data = "html/google.html"
text = data.get_file
scrape = Scrape.new(text)

# scrape.show
# puts scrape.root.html.body.div.center.div[5].list

target = scrape.access do 
  "/html/head/body/div[2]/div/div/div[8]/div[2]/div/div[2]/div/ol/li[2]/div/div[2]/span"
end

target.show
