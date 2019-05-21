class EmacsPlus < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftp.gnu.org/gnu/emacs/emacs-26.2.tar.xz"
  mirror "https://ftpmirror.gnu.org/emacs/emacs-26.2.tar.xz"
  sha256 "151ce69dbe5b809d4492ffae4a4b153b2778459de6deb26f35691e1281a9c58e"

  # Opt-out
  option "without-cocoa",
         "Build a non-Cocoa version of Emacs"
  option "without-libxml2",
         "Build without libxml2 support"
  option "without-modules",
         "Build without dynamic modules support"

  # Opt-in
  option "with-ctags",
         "Don't remove the ctags executable that Emacs provides"

  option "with-no-frame-refocus", "Disables frame re-focus (ie. closing one frame does not refocus another one)"

  # Emacs 26.x and Emacs 27.x experimental stuff
  option "with-x11", "Experimental: build with x11 support"

  # Emacs 27.x only
  option "with-pdumper",
         "Experimental: build from pdumper branch and with
         increasedremembered_data size (--HEAD only)"
  option "with-xwidgets",
         "Experimental: build with xwidgets support (--HEAD only)"
  option "with-jansson",
         "Build with jansson support (--HEAD only)"

  # Disable some experimental stuff on Mojave
  if MacOS.full_version >= "10.14"
    if build.with? "x11"
      odie "--with-x11 is not supported on Mojave yet"
    end
    if build.with? "pdumper"
      odie "--with-pdumper is not supported on Mojave yet"
    end
    if build.with? "xwidgets"
      odie "--with-xwidgets is not supported on Mojave yet"
    end
  end

  head do
    if build.with? "pdumper"
      url "https://github.com/emacs-mirror/emacs.git", :branch => "pdumper"
    else
      url "https://github.com/emacs-mirror/emacs.git"
    end

    depends_on "autoconf" => :build
    depends_on "gnu-sed" => :build
    depends_on "texinfo" => :build
  end

  deprecated_option "cocoa" => "with-cocoa"
  deprecated_option "keep-ctags" => "with-ctags"
  deprecated_option "with-d-bus" => "with-dbus"

  depends_on "pkg-config" => :build
  depends_on "little-cms2" => :recommended
  depends_on :x11 => :optional
  depends_on "dbus" => :optional
  depends_on "gnutls" => :recommended
  depends_on "librsvg" => :recommended

  depends_on "mailutils" => :optional

  if build.head?
    # Emacs 27.x (current HEAD) does support ImageMagick 7
    depends_on "imagemagick@7" => :recommended
    depends_on "imagemagick@6" => :optional
  else
    # Emacs 26.x does not support ImageMagick 7:
    # Reported on 2017-03-04: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=25967
    depends_on "imagemagick@6" => :recommended
  end

  depends_on "jansson" => :optional

  if build.with? "x11"
    depends_on "freetype" => :recommended
    depends_on "fontconfig" => :recommended
  end

  if build.with? "xwidgets"
    unless build.head?
      odie "--with-xwidgets is supported only on --HEAD"
    end
    unless build.with? "cocoa"
      odie "--with-xwidgets is supported only on cocoa via xwidget webkit"
    end
    patch do
      url "https://gist.githubusercontent.com/fuxialexander/0231e994fd27be6dd87db60339238813/raw/b30c2d3294835f41e2c8afa1e63571531a38f3cf/0_all_webkit.patch"
      sha256 "f35b955aef31537d2ff163ec9bfcc2176dbcd0ea64f05440d98ec2988b82ce25"
    end
  end

  if build.with? "no-frame-refocus"
    patch do
      url "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/no-frame-refocus-cocoa.patch"
      sha256 "abe68896ab1043dbdf17830af4ff3b83667412a0bddb1cfe04cfaae5e83e41ca"
    end
  end

  if build.with? "pdumper"
    unless build.head?
      odie "--with-pdumper is supported only on --HEAD"
    end
  end

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
    ]

    if build.with? "libxml2"
      args << "--with-xml2"
    else
      args << "--without-xml2"
    end

    if build.with? "dbus"
      args << "--with-dbus"
    else
      args << "--without-dbus"
    end

    if build.with? "gnutls"
      args << "--with-gnutls"
    else
      args << "--without-gnutls"
    end

    # Note that if ./configure is passed --with-imagemagick but can't find the
    # library it does not fail but imagemagick support will not be available.
    # See: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=24455
    if build.with?("imagemagick@6") || build.with?("imagemagick@7")
      args << "--with-imagemagick"
    else
      args << "--without-imagemagick"
    end

    # Emacs 27.x (current HEAD) supports imagemagick7 but not Emacs 26.x
    if build.with? "imagemagick@7"
      imagemagick_lib_path =  Formula["imagemagick@7"].opt_lib/"pkgconfig"
      unless build.head?
        odie "--with-imagemagick@7 is supported only on --HEAD"
      end
      ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
      ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path
    elsif build.with? "imagemagick@6"
      imagemagick_lib_path =  Formula["imagemagick@6"].opt_lib/"pkgconfig"
      ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
      ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path
    end

    if build.with? "jansson"
      unless build.head?
        odie "--with-jansson is supported only on --HEAD"
      end
      args << "--with-json"
    end

    args << "--with-modules" if build.with? "modules"
    args << "--with-rsvg" if build.with? "librsvg"
    args << "--without-pop" if build.with? "mailutils"
    args << "--with-xwidgets" if build.with? "xwidgets"

    if build.head?
      ENV.prepend_path "PATH", Formula["gnu-sed"].opt_libexec/"gnubin"
      system "./autogen.sh"
    end

    if build.with? "cocoa"
      args << "--with-ns" << "--disable-ns-self-contained"

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

      (bin/"run-emacs").write <<~EOS
#!/bin/bash

EMACS=/usr/local/bin/emacs
EMACSCLIENT=/usr/local/bin/emacsclient

export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LC_CTYPE=zh_CN.UTF-8
export LC_ALL=

ARCH=`uname`


if [ ! -f $EMACS ]; then
    echo "Can't find proper executable emacs..."
    exit 1
fi

_is_emacs_daemon_started () {
    netstat -nl 2> /dev/null | awk '{print $NF}' | grep -q "emacs.*server"
}

_is_emacs_window_exist () {
    _is_emacs_daemon_started && \
        $EMACSCLIENT -e '(<= 2 (length (visible-frame-list)))' | grep -q -x t
}

_raise_emacs() {
    if [ $ARCH = 'Linux' ]; then
        which wmctrl > /dev/null 2>&1 && wmctrl -xa "emacs.Emacs"
    elif [ $ARCH = 'Darwin' ]; then
        osascript -e 'tell application "Emacs" to activate'
    else
        echo "Unsupported platform"
    fi
}

start_emacs ()
{
    $EMACS --daemon
    return $?
}

main () {
    _is_emacs_daemon_started
    if [ $? -ne 0 ] ; then
        start_emacs
        if [ $? -eq 0 ]; then
            echo ' [sucess]'
        else
            echo ' [faild]'
            return 1
        fi
    fi

    while [ 1 ]; do
        _is_emacs_daemon_started
        if [ $? -ne 0 ]; then
            echo "Waiting emacs to be started..."
            sleep 1
        else
            break
        fi
    done

    # Simply return if --daemon is set. This is only used by systemd.
    if [ "$1" = "--daemon" ]; then
        return 0
    fi

    # Get arguments passed to emacsclient.
    local args=""
    while getopts tnc var; do
        case $var in
            t)
                args="-t";;
            n)
                args="-n";;
            c)
                args="-c";;
            *)
                printf "Usage: %s [-t/-n] [-c] file:line" $0
                ;;
        esac
    done
    shift $(($OPTIND - 1))

    if [ -z "$args" ]; then
        if [ "$ARCH" = 'Linux' ]; then
            if [ -z $DISPLAY ]; then
                # Always opens new frame if working in command-line mode (without X).
                args="-t $args"
            else
                # Don't wait if working under X.
                args="-n  $args"
            fi
        elif [ "$ARCH" = 'Darwin' ]; then
            args="-n"
        fi
    fi

    _is_emacs_window_exist || args="$args -c"

    $EMACSCLIENT $args -u "$@"
    if [ $? -eq 0 ]; then
        _raise_emacs
    fi
}

main "$@"
      EOS



    else
      if build.with? "x11"
        # These libs are not specified in xft's .pc. See:
        # https://trac.macports.org/browser/trunk/dports/editors/emacs/Portfile#L74
        # https://github.com/Homebrew/homebrew/issues/8156
        ENV.append "LDFLAGS", "-lfreetype -lfontconfig"
        args << "--with-x"
        args << "--with-gif=no" << "--with-tiff=no" << "--with-jpeg=no"
      else
        args << "--without-x"
      end
      args << "--without-ns"

      system "./configure", *args
      system "make"
      system "make", "install"
    end

    # Follow MacPorts and don't install ctags from Emacs. This allows Vim
    # and Emacs and ctags to play together without violence.
    if build.without? "ctags"
      (bin/"ctags").unlink
      (man1/"ctags.1.gz").unlink
    end
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
