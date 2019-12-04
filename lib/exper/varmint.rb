require 'ostruct'

class OpenStruct
  def to_s
    "[not a value]"
  end

  def inspect
    to_s
  end
end

class OpenVar

  def initialize
    @hash = {}
    @obj = OpenStruct.new
  end

  def [](var)
puts "self = #{self.inspect}"
#   @hash[var] = nil
    pieces = var.split(".")
    this = @obj
    pieces.each do |piece|
puts "piece = #{piece}"
#     this.send(piece.to_s+"=", OpenStruct.new)
      this = this.send(piece)
puts "this = #{this.inspect}"
    end
    this
  end

  def method_missing(meth, *args)
    setter = meth.to_s + "="
    meh = @obj.send(setter, OpenStruct.new)
    @obj
  end


end

var = OpenVar.new

var.foo.bar = 237

puts var.foo.inspect
puts var.foo.bar.inspect

puts var["foo.bar"]
