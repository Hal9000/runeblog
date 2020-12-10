
# Check integrity of runeblog repo
# Making this up as I go along

def file_exists(fname, under=Dir.pwd)
  puts "  File #{fname} not found under #{under}" unless File.exist?(fname)
end

def dir_exists(dname, under=Dir.pwd)
  puts "  Dir #{dname} not found under #{under}" unless Dir.exist?(dname)
end

def file_contents(fname)
  text = File.read(fname).chomp.inspect
  printf "    Contents of %-15s : %s\n", fname, text
end

def file_lines(fname)
  n = File.readlines(fname).size
  printf "    # lines in  %-15s = %d\n", fname, n
end

def get_sequence
  File.read("#{Repo}/data/sequence").chomp.to_i
end


def get_max_draft_num
  str = Dir["#{Repo}/drafts/*.lt3"].sort.last
  str.sub(%r{.*/}, "").to_i
end

####################################


Start = Dir.pwd     # parent of .blogs dir

puts

## Repo root exists?
abort "  No .blogs repo" unless Dir.exist?(".blogs")

Repo = "#{Start}/.blogs"

## repo root/data exists?
abort "  No data/ under repo" unless Dir.exist?(".blogs/data")

Dir.chdir(".blogs")

## Expected dirs under root
dirs = %w[config drafts posts views widgets]
dirs.each {|dir| dir_exists(dir) }

Dir.chdir("data")

## Expected files under root/data
expecting = %w[EDITOR ROOT VERSION VIEW features.txt global.lt3
               sequence universal.lt3]

expecting.each {|fname| file_exists(fname) }

found = Dir["*"]
extra = found - expecting

## Extra files under root/data?
puts "  Extra files under data/: \n#{extra.inspect}\n " unless extra.empty?

## Consistent root?
root = File.read("ROOT").chomp
here = Dir.pwd[0..-5]
root.sub!(/\/$/, "")   # trim /
here.sub!(/\/$/, "")   # trim /
bad = root != here
if bad
  puts "  ROOT #{root.inspect} INCONSISTENT with current location\n     #{here.inspect}\n " if bad
else
  puts "  ROOT consistent with current location"
end
puts


## Stuff as expected under data?
puts "  Under repo/data:"
file_contents("sequence")
file_contents("EDITOR")
file_contents("VERSION")
file_contents("VIEW")

file_lines("features.txt")
file_lines("global.lt3")
file_lines("universal.lt3")

Dir.chdir("../../.blogs")   # back to top

## Consistent sequence numbers?
seqnum = get_sequence
maxnum = get_max_draft_num
ok = seqnum == maxnum
puts
printf ok ? "  Consistent:" : "  INCONSISTENT!"
puts "   Current seq# is #{seqnum}; highest-numbered draft = #{maxnum}"
puts


