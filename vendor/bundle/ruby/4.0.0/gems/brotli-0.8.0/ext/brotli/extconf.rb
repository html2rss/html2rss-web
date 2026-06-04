require "mkmf"
require "fileutils"
require "rbconfig"

dir_config("brotli")
have_func("rb_gc_mark_movable")

# libbrotli-dev
have_dev_pkg = [
  have_header("brotli/decode.h"),
  have_header("brotli/encode.h"),
  pkg_config("libbrotlicommon"),
  pkg_config("libbrotlidec"),
  pkg_config("libbrotlienc")
].all? { |e| e }

have_header("brotli/shared_dictionary.h")
have_func("BrotliEncoderPrepareDictionary", "brotli/encode.h")
have_func("BrotliEncoderAttachPreparedDictionary", "brotli/encode.h")
have_func("BrotliDecoderAttachDictionary", "brotli/decode.h")

if enable_config("vendor")
  have_dev_pkg = false
  Logging::message "Use vendor brotli\n"
  $defs << "-DHAVE_BROTLI_SHARED_DICTIONARY_H"
  $defs << "-DHAVE_BROTLIENCODERPREPAREDICTIONARY"
  $defs << "-DHAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY"
  $defs << "-DHAVE_BROTLIDECODERATTACHDICTIONARY"
end

$CPPFLAGS << " -DOS_MACOSX" if RbConfig::CONFIG["host_os"] =~ /darwin|mac os/
$INCFLAGS << " -I$(srcdir)/enc -I$(srcdir)/dec -I$(srcdir)/common -I$(srcdir)/include" unless have_dev_pkg

create_makefile("brotli/brotli")

unless have_dev_pkg
  ext_dir = __dir__
  vendor_dir = File.expand_path("../../vendor/brotli/c", __dir__)
  objext = RbConfig::CONFIG["OBJEXT"]

  %w[enc dec common include].each do |dirname|
    FileUtils.rm_rf dirname
    FileUtils.mkdir_p dirname
    FileUtils.cp_r(File.join(vendor_dir, dirname), ext_dir)
  end

  srcs = []
  objs = []
  Dir[File.expand_path(File.join("{enc,dec,common,include}", "**", "*.c"), ext_dir)].sort.each do |file|
    file["#{ext_dir}#{File::SEPARATOR}"] = ""
    srcs << file
    objs << file.sub(/\.c\z/, ".#{objext}")
  end

  makefile = File.read("Makefile")
  makefile = makefile
             .sub(/^ORIG_SRCS = .*$/, "ORIG_SRCS = brotli.c buffer.c #{srcs.join(" ")}")
             .sub(/^OBJS = .*$/, "OBJS = brotli.#{objext} buffer.#{objext} #{objs.join(" ")}")
  File.write("Makefile", makefile)
end
