def create_dir(dir)   # FIXME move later
  cmd = "mkdir -p #{dir} >/dev/null 2>&1"
  result = system(cmd) 
  raise "Can't create #{dir}" unless result
end

def interpolate(str)
  wrap = "<<-EOS\n#{str}\nEOS"
  eval wrap
end

def error(err)  # FIXME - this is duplicated
  str = "\n  Error: #{err}"
  puts str
  puts err.backtrace  # [0]
end

