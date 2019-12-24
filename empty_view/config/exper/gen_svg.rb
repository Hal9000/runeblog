width = 550
title = "My Stuff"   # 13 -> 58, 8 -> 13/8 * 58
sub   = "I always wanted a place for it"  # 22 -> 24, 31 -> 15

tlen, slen = title.length, sub.length
tfont = 58
sfont = 18

=begin
.svg_titles
title      style: bold size: 20px face: sans-serif color: white
title2     italic 10px sans-serif
width      550
height     90
bgcolor    blue
title_xy   82 55 left
title2_xy  210 80
.end
=end

puts <<-EOS
.nopara
.variables
blog          #{title}
blog.desc     #{sub}

viewbox.wide  550
viewbox.high  90

rect.wide     550
rect.high     90
rect.fill     blue

title.font    bold #{tfont}px sans-serif
title.fill    white
title.xoff    82
title.yoff    55

subtitle.font italic #{sfont}px sans-serif
subtitle.fill lightblue
subtitle.xoff 210
subtitle.yoff 80
.end

<svg width=$viewbox.wide height=$viewbox.high 
     viewBox="0 0 $viewbox.wide $viewbox.high" 
     xmlns="http://www.w3.org/2000/svg">
  <style>
    .subtitle { font: $subtitle.font; fill: $subtitle.fill }
    .title    { font: $title.font; fill: $title.fill }
  </style>

<rect x="0" y="0" rx="10" ry="10" width="$rect.wide" height="$rect.high" fill="$rect.fill"/>

<text x=$title.xoff y=$title.yoff class=title>$blog</text>
<text x=$subtitle.xoff y=$subtitle.yoff class=subtitle>$blog.desc</text>
</svg>
<br>
Here we are
EOS
