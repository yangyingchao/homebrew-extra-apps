class EmacsPlus < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftp.gnu.org/gnu/emacs/emacs-26.2.tar.xz"
  mirror "https://ftpmirror.gnu.org/emacs/emacs-26.2.tar.xz"
  sha256 "151ce69dbe5b809d4492ffae4a4b153b2778459de6deb26f35691e1281a9c58e"

  # Opt-in
  depends_on "pkg-config" => :build
  depends_on "little-cms2" => :recommended
  depends_on "gnutls" => :recommended
  depends_on "mailutils" => :optional
  depends_on "imagemagick@7" => :recommended

  def install
    args = %W[
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp
      --infodir=#{info}/emacs
      --prefix=#{prefix}
    ]

    args << "--with-xml2"
    args << "--without-dbus"
    args << "--without-gnutls"
    args << "--with-imagemagick"

    imagemagick_lib_path =  Formula["imagemagick@7"].opt_lib/"pkgconfig"
    ohai "ImageMagick PKG_CONFIG_PATH: ", imagemagick_lib_path
    ENV.prepend_path "PKG_CONFIG_PATH", imagemagick_lib_path

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
