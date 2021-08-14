{ lib
, runCommandNoCC
, writeScript
, writeText
, mkExtraUtils
, nukeReferences

# Additional software
, busybox
, ply-image
, glibc

}:

#
# This is a WIP initramfs.
#
# This is not meant to stay, and most of what is present here will be removed
# and transformed into discrete modules for stage-1.
#

let
  issue = writeText "etc-issue" ''
                                 dP oo          
                                 88             
    .d8888b. 88d8b.d8b. .d8888b. 88 dP dP.  .dP 
    Y8ooooo. 88'`88'`88 88'  `88 88 88  `8bd8'  
          88 88  88  88 88.  .88 88 88  .d88b.  
    `88888P' dP  dP  dP `88888P' dP dP dP'  `dP 

      +----------------------------------+
      | Tip of the day                   |
      | ==============                   |
      | Login with root and no password. |
      +----------------------------------+

  '';

  # https://git.busybox.net/busybox/tree/examples/inittab
  inittab = writeText "inittab" ''
    console::respawn:${extraUtils}/bin/getty -l ${extraUtils}/bin/login 0 console

    #::sysinit:${extraUtils}/bin/ply-image --clear=0x0000ff # lime
    #::wait:${extraUtils}/bin/ply-image --clear=0xff0000    # red
    #::once:${extraUtils}/bin/ply-image --clear=0x009900    # green means go

    ::restart:/bin/init
    ::ctrlaltdel:/bin/poweroff
  '';

  passwd = writeText "passwd" ''
    root::0:0:root:/root:${extraUtils}/bin/sh
  '';

  profile = writeText "profile" ''
    export LD_LIBRARY_PATH="${extraUtils}/lib"
    export PATH="${extraUtils}/bin"
  '';

  init = writeScript "init" ''
    #!${extraUtils}/bin/sh

    echo
    echo "::"
    echo ":: Setting up system"
    echo "::"
    echo

    . /etc/profile

    (
      PS4=" $ "
      set -x
      mount -t proc proc /proc
      mount -t sysfs sys /sys
      mount -t devtmpfs devtmpfs /dev
    )

    (
    for i in  1 2 3 4 5 6 7 8 9 a b c d e f; do
      ply-image --clear=0x$i$i$i$i$i$i &
      # The background and wait helps on slower platforms.
      sleep 0.01
      wait
    done
    ply-image --clear=0xffffff /etc/splash.png
    ) &

    (
      PS4=" $ "
      set -x
      hostname smolix-demo
      ip link set lo up
    )

    if [ -e /proc/sys/kernel/printk ]; then
      (
        PS4=" $ "
        set -x
        echo 5 > /proc/sys/kernel/printk
      )
    fi

    echo
    echo "::"
    echo ":: Launching busybox linuxrc"
    echo "::"
    echo

    wait

    exec linuxrc
  '';

  extraUtils = mkExtraUtils {
    name = "smolix--extra-utils";
    packages = [
      {
        package = busybox;
        extraCommand = ''
          (cd $out/bin/; ln -s busybox linuxrc)
        '';
      }
      {
        package = ply-image;
        extraCommand = ''
          cp -f ${glibc.out}/lib/libpthread.so.0 $out/lib/
        '';
      }
    ]
    ;
  };
in

runCommandNoCC "minimal-initramfs" {
  nativeBuildInputs = [
    nukeReferences
  ];
  passthru = {
    inherit extraUtils;
  };
} ''
  mkdir -p $out

  mkdir -p $out/${builtins.storeDir}
  cp -prv ${extraUtils} $out/${builtins.storeDir}

  cp -vr ${init} $out/init

  mkdir -p $out/etc

  cp ${inittab} $out/etc/inittab
  cp ${issue} $out/etc/issue
  cp ${passwd} $out/etc/passwd
  cp ${profile} $out/etc/profile
  cp ${../../artwork/splash.png} $out/etc/splash.png

  # POSIX requires /bin/sh
  mkdir -p $out/bin
  ln -s ${extraUtils}/bin/sh $out/bin/sh
  (
  cd $out
  find -type d -printf 'dir   /%h/%f 755 0 0 \n'
  find -type f -printf 'file  /%h/%f '"$out/"'%h/%f %m  0 0 \n'
  find -type l -printf 'slink /%h/%f %l %m  0 0 \n'
  ) > ./files.list
  mv files.list $out/
  sed -i -e 's;/\./;/;g' $out/files.list

  # Add more files to the initramfs
  cat >> $out/files.list <<EOF

  dir /proc 755 0 0
  dir /sys 755 0 0
  dir /mnt 755 0 0
  dir /root 755 0 0

  dir /dev 755 0 0
  nod /dev/console 644 0 0 c 5 1
  nod /dev/loop0   644 0 0 b 7 0
  EOF
''
