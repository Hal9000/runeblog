def sublist
  title = api.data
  var, title = title.split(" ", 2)
  lines = api.body.to_a
  lines.map! do |line|
    line = line.chomp
    line = "<font color=red>#{line[1..-1]}</font>" if line[0] == "=" || line[0] == "!"
    line = "<li>#{line}</li>"
  end
  text = lines.join("\n")
  text = "&nbsp;&nbsp;<b>#{title}</b><br><ul>" + text + "</ul>"
  api.setvar var, text
end

class Livetext::Functions

def split(param)
  param.dup.gsub!(" || ", "\n")
end

def dd(param)
  "$$" + param
end

end
