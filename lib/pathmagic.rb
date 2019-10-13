module PathSep
  def /(right)
    s1 = self.to_s.dup
    s2 = right.to_s.dup
    s1 << "/" unless s1.end_with?("/") || s2.start_with?("/")
    path = s1 + s2
    path.gsub!("//", "/")
    path
  end
end

String.include(PathSep)
Symbol.include(PathSep)

