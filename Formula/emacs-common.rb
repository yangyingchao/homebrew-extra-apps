#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
class EmacsCommon < Formula
  desc "GNU Emacs text editor"
  homepage "https://www.gnu.org/software/emacs/"
  url "file:///dev/null"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  version "1.0"

  def install
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
end
