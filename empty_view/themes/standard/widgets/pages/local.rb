# Custom code for 'pages' widget

children = Dir["*.lt3"] - ["pages.lt3"]
children.each do |child|
  dest = child.sub(/.lt3$/, ".html")
  xlate src: child, dst: dest  # , debug: true
end

