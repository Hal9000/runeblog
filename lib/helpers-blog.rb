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

def read_config(file, *syms)
  lines = File.readlines(file).map(&:chomp)
  obj = OpenStruct.new
  lines.each do |line|
    key, val = line.split(" ", 2)
    key = key[0..-2] # remove colon
    obj.send(key+"=", val)
  end
  @deployer = RuneBlog::Deployment.new(obj)
  obj
rescue => err
  puts "Something hit the fan: #{err}"
  puts err.backtrace
  exit
end

def write_config(obj, file)
  hash = obj.to_h
  File.open(file, "w") do |f| 
    hash.each_pair do |key, val|
      f.puts "#{key}: #{val}"
    end
  end
end

