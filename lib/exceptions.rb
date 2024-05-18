
def make_exception(sym, str, target_class = Object)
  return if target_class.constants.include?(sym)

  target_class.const_set(sym, StandardError.dup)
  define_method(sym) do |*args|
    msg = str.dup
    args.each.with_index {|arg, i| msg.sub!("%#{i+1}", arg) }
    target_class.class_eval(sym.to_s).new(msg)
  end
end

make_exception(:NotImplemented,        "Feature not yet implemented")
make_exception(:CantOpen,              "Can't open '%1'")
make_exception(:CantDelete,            "Can't delete '%1'")
make_exception(:InternalError,         "Glitch: %1 got arg '%2'")
make_exception(:CantCopy,              "Can't copy %1 to %2")

make_exception(:FileNotFound,          "File %1 was not found")
make_exception(:FoundNeither,          "Found neither %1 nor %2")
make_exception(:BlogRepoAlreadyExists, "Blog repo %1 already exists")
make_exception(:CantAssignView,        "%1 is not a view")
make_exception(:ViewAlreadyExists,     "View %1 already exists")
make_exception(:DirAlreadyExists,      "Directory %1 already exists")
make_exception(:CantCreateDir,         "Can't create directory %1")
make_exception(:EditorProblem,         "Could not edit %1")
make_exception(:NoSuchView,            "No such view: %1")
make_exception(:NoBlogAccessor,        "Runeblog.blog is not set")
make_exception(:ExpectedString,        "Expected nonempty string but got %1 (%2)")
make_exception(:ExpectedView,          "Expected string or View object but got %1 (%2)")
make_exception(:ExpectedInteger,       "Expected integer but got %1 (%2)")
make_exception(:NoPostCall,            "Method #post not called (no metadata)")
make_exception(:CantFindWidgetDir,     "Can't find widget dir '%1'")
make_exception(:PublishError,          "Error during publishing")
make_exception(:NoNumericPrefix,       "No numeric prefix on slug '%1'")
make_exception(:NoExtensionExpected,   "No file extension expected on '%1'")
make_exception(:FilenameHasBlank,      "File '%1' contains a blank space.")

make_exception(:MissingGlobal,         "File global.lt3 is missing.")

