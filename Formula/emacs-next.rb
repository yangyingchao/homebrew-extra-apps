class EmacsNext < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://github.com/emacs-mirror/emacs.git"
  version "head"


  depends_on "emacs-common"

  depends_on "autoconf" => :build
  depends_on "gnu-sed" => :build
  depends_on "texinfo" => :build
  depends_on "pkg-config" => :build
  depends_on "gnutls"
  depends_on "little-cms2"
  depends_on "imagemagick@7"
  depends_on "jansson"


  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
      --with-xml2
      --with-lcms2
      --without-dbus
      --with-imagemagick
      --with-json
      --with-ns
      --with-gnutls
      --disable-ns-self-contained
      --without-gameuser
      --without-gpm
      --without-pop
      --without-mailutils
    ]

    imagemagick_lib_path =  Formula["imagemagick@7"].opt_lib/"pkgconfig"
    ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
    ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path

    gnutls_lib_path =  Formula["gnutls"].opt_lib/"pkgconfig"
    ohai "GnuTLS PKG_CONFIG_PATH: ", gnutls_lib_path
    ENV.prepend_path "PKG_CONFIG_PATH", gnutls_lib_path

    ENV.prepend_path "PATH", Formula["gnu-sed"].opt_libexec/"gnubin"

    system "./autogen.sh"

    system "./configure", *args
    system "make"
    system "make", "install"

    icons_dir = buildpath/"nextstep/Emacs.app/Contents/Resources"

    prefix.install "nextstep/Emacs.app"

    # Replace the symlink with one that avoids starting Cocoa.
    (bin/"emacs").unlink # Kill the existing symlink
    (bin/"emacs").write <<~EOS
        #!/bin/bash
        exec #{prefix}/Emacs.app/Contents/MacOS/Emacs "$@"
      EOS

    (bin/"ctags").unlink
    (man1/"ctags.1.gz").unlink
  end

  plist_options manual: "emacs"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/emacs</string>
        <string>--fg-daemon</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>StandardOutPath</key>
      <string>/tmp/homebrew.mxcl.emacs-plus.stdout.log</string>
      <key>StandardErrorPath</key>
      <string>/tmp/homebrew.mxcl.emacs-plus.stderr.log</string>
    </dict>
    </plist>
    EOS
  end

  def caveats
    <<~EOS
      Emacs.app was installed to:
        #{prefix}

      To link the application to default Homebrew App location:
        brew linkapps
      or:
        ln -s #{prefix}/Emacs.app /Applications

    EOS
  end

  test do
    assert_equal "4", shell_output("#{bin}/emacs --batch --eval=\"(print (+ 2 2))\"").strip
  end
end
