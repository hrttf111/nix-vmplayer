#!/usr/bin/env bash
#
# VMware Installer Launcher
#
# This is the executable stub to check if the VMware Installer Service
# is installed and if so, launch it.  If it is not installed, the
# attached payload is extracted, the VMIS is installed, and the VMIS
# is launched to install the bundle as normal.

# Architecture this bundle was built for (x86 or x64)
ARCH=x64

if [ -z "$BASH" ]; then
   # $- expands to the current options so things like -x get passed through
   if [ ! -z "$-" ]; then
      opts="-$-"
   fi

   # dash flips out of $opts is quoted, so don't.
   exec /usr/bin/env bash $opts "$0" "$@"
   echo "Unable to restart with bash shell"
   exit 1
fi

set -e

ETCDIR=/etc/vmware-installer
OLDETCDIR="/etc/vmware"

### Offsets ###
# These are offsets that are later used relative to EOF.
FOOTER_SIZE=52

# This won't work with non-GNU stat.
FILE_SIZE=`stat --format "%s" "$0"`
offset=$(($FILE_SIZE - 4))

MAGIC_OFFSET=$offset
offset=$(($offset - 4))

CHECKSUM_OFFSET=$offset
offset=$(($offset - 4))

VERSION_OFFSET=$offset
offset=$(($offset - 4))

PREPAYLOAD_OFFSET=$offset
offset=$(($offset - 4))

PREPAYLOAD_SIZE_OFFSET=$offset
offset=$(($offset - 4))

LAUNCHER_SIZE_OFFSET=$offset
offset=$(($offset - 4))

PAYLOAD_OFFSET=$offset
offset=$(($offset - 4))

PAYLOAD_SIZE_OFFSET=$offset
offset=$(($offset - 4))

# Rest of the offsets ommitted

### End offsets ###

# Short name (ie, vmware-workstation).  This isn't technically correct
# since there could be multiple product components in a bundle.
PRODUCT_NAME=vmware-player

# Called when the script exits
#
# Arguments:
#    None
#
# Side effects:
#    - VMIS_TEMP and PREPAYLOAD is removed unless VMIS_KEEP_TEMP is set
on_exit() {
   if [ -e "$VMIS_TEMP" -a -z "$VMIS_KEEP_TEMP" ]; then
      rm -rf "$VMIS_TEMP"
   fi

   if [ -e "$PREPAYLOAD" -a -z "$VMIS_KEEP_TEMP" ]; then
      rm -rf "$PREPAYLOAD"
   fi
}

#trap on_exit EXIT
trap "" USR1

# Retrives and sets the various lengths that are extracted from the
# footer of the file.
#
# Arguments:
#    $1 => bundle to get the lengths from
#
# Side effects:
#    - MAGIC_NUMBER, LAUNCHER_SIZE, and PAYLOAD_SIZE are set.
#
# Returns:
#    0 if successful, else 1
set_lengths() {
   local file="$1"
   if [ ! -s "$file" ]; then
      echo "$file does not exist"
      exit 1
   fi

   # XXX: put extraction in its own function
   MAGIC_NUMBER=`od -An -t u4 -N 4 -j $MAGIC_OFFSET "$file" | tr -d ' '`

   #if [ "$MAGIC_NUMBER" != "907380241" ]; then
   #   echo "magic number does not match"
   #   exit 1
   #fi

   LAUNCHER_SIZE=`od -An -t u4 -N 4 -j $LAUNCHER_SIZE_OFFSET "$file" | tr -d ' '`
   PAYLOAD_SIZE=`od -An -t u4 -N 4 -j $PAYLOAD_SIZE_OFFSET "$file" | tr -d ' '`
   PREPAYLOAD_SIZE=`od -An -t u4 -N 4 -j $PREPAYLOAD_SIZE_OFFSET "$file" | tr -d ' '`

   SKIP_BYTES=$(($PREPAYLOAD_SIZE + $LAUNCHER_SIZE))

   return 0
}

# Determines whether the user land is 32 or 64-bit.
#
# Side effects:
#    None.
#
# Returns:
#    "x86" or "x64" on success with error code 0.  Exits with non-zero
#    status and undefined text on failure.
get_arch() {
   # First byte is the ELF magic number.  The 5th byte is whether it's
   # a 32 or 64-bit machine (1 or 2, respectively).  See `man elf` for
   # details.
   local ELF_MAGIC=7f

   if [ "`od -N1 -An -t x1 < /bin/sh | tr -d ' '`" != "$ELF_MAGIC" ]; then
      exit 1
   fi

   local arch=`od -j4 -N1 -An -t u1 < /bin/sh | tr -d ' '`

   case $arch in
      1)
         echo "x86"
	 exit 0
	 ;;
      2)
         echo "x64"
         exit 0
	 ;;
      *)
         exit 1
         ;;
   esac
}

# Determines if path is relative.
#
# Side effects:
#    None.
#
# Returns:
#    0 if relative, otherwise 1.
is_relative() {
    local path="$1"
    shift

    [ "${path:0:1}" != "/" ]
    return
}

# Extracts the payload data into a temporary directory.
#
# Side effects:
#    - temporary directory is created
#    - VMIS_TEMP is set to temporary directory
#
# Returns:
#    None
extract_self() {
   VMIS_TEMP=`mktemp -d /tmp/vmis.XXXXXX`
   local file="$0"
   local filter=""
   local bootstrapper="$PREPAYLOAD"/bootstrapper-gtk

   if [ ! -d "$VMIS_TEMP" ]; then
      echo "Unable to create temporary directory."
      exit 1
   fi

   if is_relative "$file"; then
      file="$PWD/$file"
   fi

   if [ -e "$bootstrapper" ] && "$bootstrapper" --validate 2> /dev/null; then
      filter=' | "$PREPAYLOAD"/bootstrapper-gtk --title "VMware Installer" \
                --message "Please wait while extracting the VMware Installer..." \
                --total $PAYLOAD_SIZE"'
   else
      echo -n "Extracting VMware Installer..."
   fi

   (cd $VMIS_TEMP && dd if="$file" ibs=$SKIP_BYTES obs=1024 skip=1 2> /dev/null \
      $filter | gunzip -c 2> /dev/null | tar -xf - 2> /dev/null)

   if [ ! -e "$bootstrapper" ]; then
      echo "done."
   fi
}

extract_prepayload() {
   PREPAYLOAD=`mktemp -d /tmp/vmis.XXXXXX`
   local file="$0"

   if [ ! -d "$PREPAYLOAD" ]; then
      echo "Unable to create temporary directory."
      exit 1
   fi

   if is_relative "$file"; then
      file="$PWD/$file"
   fi

   (cd $PREPAYLOAD && dd if="$file" ibs=$LAUNCHER_SIZE obs=1024 skip=1 2> /dev/null | \
      gunzip -c 2> /dev/null | tar -xf - 2> /dev/null)
}

# Determines if a program is in the user's PATH.  This is used instead
# of the external which because Solaris' version does not work as
# expected.
#
# Side effects:
#    None
#
# Arguments:
#    $1 => program to check
#
# Returns:
#    0 if found, else 1
internal_which() {
   local binary="$1"

   for dir in `echo $PATH | tr ":" "\n"`; do
      if [ -s "$dir/$binary" -a -x "$dir/$binary" ]; then
         return 0
      fi
   done

   return 1
}


# Installs the installer and the current bundle.
#
# Arguments:
#    $1 => file source
#    $2 => true if show help
#    $3 => path to bundle
#
# Returns:
#    None
install() {
   local source="$1"/install
   shift
   local help="$1"
   shift
   local bundle="$1"
   shift

   if [ ! -d "$source" ]; then
      echo "$source does not exist" >&2
      exit 1
   fi

   export VMWARE_BOOTSTRAP="$VMIS_TEMP"/bootstrap

   cp -f "$source"/vmware-installer/bootstrap "$VMWARE_BOOTSTRAP"
   sed -i -e "s,@@LIBDIR@@,$source,g" "$VMWARE_BOOTSTRAP"
   sed -i -e "s,@@VMWARE_INSTALLER@@,$source/vmware-installer,g" "$VMWARE_BOOTSTRAP"

   . "$VMWARE_BOOTSTRAP"

   local installer="$VMWARE_INSTALLER"/vmware-installer

   if [ -n "$help" ]; then
      "$installer" --help
      exit 0
   fi

   # We must fixup the paths in Pango or the fonts will be all messed up
   local libconf="$source"/vmware-installer/lib/libconf
   for file in etc/pango/pangorc etc/pango/pango.modules etc/pango/pangox.aliases \
               etc/gtk-2.0/gdk-pixbuf.loaders etc/gtk-2.0/gtk.immodules; do
       sed -i -e "s,@@LIBCONF_DIR@@,$libconf,g" "$libconf/$file"
   done

   # Pass all options the user passed in so that the correct UI type
   # gets set.
   "$installer" --set-setting vmware-installer libconf "$libconf"   \
                --install-component "$source"/vmware-installer      \
                --install-bundle "$bundle" "$@"
   ret=$?
   if [ $ret != 0 ]; then
      exit $ret
   fi

   return 0
}


# Uninstall existing bundle installation.
#
# Arguments:
#    $1 => etcdir
#    $2 => suffix to add to vmware-uninstall (ie -vix)
#
# Returns:
#    0 on success
uninstall_bundle() {
   etcdir="$1"
   shift
   suffix="$1"
   shift

   local bootstrap="$etcdir"/bootstrap

   # If the bootstrap file exists, we are dealing with a VMIS
   # installer.
   if [ -e "$bootstrap" ]; then
      local bindir="`. $etcdir/bootstrap && echo $BINDIR`"
      local installer="$bindir"/vmware-uninstall$suffix
      # Check if this is an old style file by checking the version
      # line for 'VERSION="1.0"'  If it's found, run the blanket
      # uninstall.
      if grep -q 'VERSION="1.0"' "$bootstrap"; then
         if [ -e "$installer" ]; then
            if ! "$installer" "$@"; then
               echo "Uninstall did not complete successfully."
               exit 1
            fi
         fi
      fi
   fi

   return 0
}


# Uninstall a tar installation.
#
# Arguments:
#    $1 => etcdir
#    $2 => suffix to add to vmware-uninstall (ie -vix)
#
# Returns:
#    0 on success
uninstall_tar() {
   etcdir="$1"
   shift
   suffix="$1"
   shift

   locations="$etcdir"/locations

   if [ -e $locations ]; then
      local bindir=`grep "^answer BINDIR " $locations | tail -n 1 | sed 's,answer BINDIR ,,g'`
      local installer="$bindir"/vmware-uninstall$suffix.pl

      if [ -e "$installer" ]; then
         echo "Uninstalling legacy installation..."
         "$installer" -d
      else			# No uninstaller present, get rid of locations db.
         rm -f $locations
      fi
   fi
}

remove_rpm() {
   local pkg="$1"
   shift

   # If normal uninstallation fails, we want to force it out.  This
   # is likely because the preun script failed.  try again with
   # --noscripts
   if ! rpm -e $pkg; then
      echo "Uninstallation of $pkg failed.  Forcing uninstallation."
      rpm -e $pkg --noscripts
   fi
}

# Uninstalls legacy Player/Workstation.
#
# Arguments:
#    None
#
# Returns:
#    0 on success.
uninstall_legacy() {
   local etcdir="$1"
   shift

   local hosted=`echo "$PRODUCT_NAME" | grep "\(vmware-workstation\|vmware-player\|vmware-server\|vmware-vix\)"`

   if [ -n "$hosted" ]; then # Check to see if rpm is installed
      for pkg in VMwareWorkstation VMwarePlayer; do
         if rpm -q $pkg > /dev/null 2>&1; then
            remove_rpm $pkg
         fi
      done
      # Now handle the server case.  The installer is normally replacing
      # Player and/or Workstation, so there is no need to explicitly let
      # the user know that we're replacing them.  Silently replacing
      # server on the other hand is not a good idea.
      if rpm -q VMware-server > /dev/null 2>&1; then
         echo "VMware Server must be removed before installation can continue."
         echo "It will be automatically uninstalled by this installer.  Press"
         echo "ctrl-C now if you do not wish to continue or if you have running"
         echo "virtual machines that must be closed."
         echo ""
         echo "Otherwise press <enter> to continue and automatically uninstall VMware Server."
         read -e NOVAR
         rpm -e --noscripts VMware-server
      fi
   fi

   uninstall_tar "$etcdir" ""

   # config was a mess under the tar/rpm.  It always got renamed and
   # crazy things.  Clean them up.
   rm -f "$etcdir"/config.[0-9]*

   # Networking is sometimes still running after stopping services so
   # forceably kill it.  If it's still running then vmnet can't be
   # removed and network settings aren't migrated properly either.
   killall --wait -9 vmnet-netifup vmnet-dhcpd vmnet-natd vmnet-bridge \
                     vmnet-detect vmnet-sniffer 2> /dev/null || true
   /sbin/rmmod vmnet 2> /dev/null || true

   return 0
}


# Uninstalls bundle rpm for Player/Workstation.
#
# Arguments:
#    None
#
# Returns:
#    None.
uninstall_rpm() {
   local hosted=`echo "$PRODUCT_NAME" | grep "\(vmware-workstation\|vmware-player\|vmware-server\|vmware-vix\)"`

   if [ -n "$hosted" ]; then # Check to see if rpm is installed
      for pkg in VMware-Workstation VMware-Player; do
         if rpm -q $pkg > /dev/null 2>&1; then
            remove_rpm $pkg
         fi
      done
   fi
}


# Migrates networking settings for Player/Workstation.
# If called on an Iron install of Workstation, it will
# do nothing.  The locations and networking files were
# located by default in /etc/vmware, hence OLDETCDIR.
# If they were installed elsewhere, we have no way to
# find them.
#
# This only works for pre-Iron.  Iron network settings
# are stored in a different directory and upgrades handled
# by VMIS.
#
# Arguments:
#    None
#
# Returns:
#    None.
migrate_networks() {
   local locations="$OLDETCDIR"/locations
   local networking="$OLDETCDIR"/networking

   if [ -e "$networking" ]; then
      local tempNetworking=`mktemp /tmp/vmwareNetworking.XXXXXX`
      cp -f "$networking" $tempNetworking
      export VMWARE_RESTORE_NETWORKING=$tempNetworking
   elif [ -e "$locations" ]; then
      local tempLocations=`mktemp /tmp/vmwareLocations.XXXXXX`
      cp -f "$locations" $tempLocations
      export VMWARE_MIGRATE_NETWORKING=$tempLocations
   fi

   return 0
}

uninstall_old_vix() {
   # VIX used to live under vmware-vix, so we need to
   # check for an older VIX there.
   uninstall_bundle /etc/vmware-vix "-vix" "$@"

   # Uninstall old VIX versions if necessary.
   uninstall_tar /etc/vmware-vix "-vix"
}

uninstall_old() {
   # Uninstall the older .bundles
   uninstall_bundle "$OLDETCDIR" "" "$@"

   # VMWARE_SKIP_RPM_UNINSTALL will be set if we're installing
   # in an rpm context. In that case, we don't want to run any
   # rpm commands to prevent rpm deadlock.
   if [ -z "$VMWARE_SKIP_RPM_UNINSTALL" ]; then
      uninstall_rpm
   fi

   # Check if we need to run the uninstall portions of this script for earlier
   # installers.  Look for the locations database in /etc/vmware.  This file
   # will only exist for pre-Iron installs.
   if [ -e "$OLDETCDIR"/locations ]; then
      # This will uninstall legacy tar/rpm installations. Note that
      # we do not need to be concerned about checking for
      # VMWARE_SKIP_RPM_UNINSTALL since the bundle rpms are marked
      # to conflict with legacy rpms.
      uninstall_legacy $OLDETCDIR

      # Check if we need to uninstall components
      uninstall_tar $OLDETCDIR ""

      uninstall_old_vix "$@"
   fi
}


# Main entry point.  Checks whether the VMIS is installed and if so launches it.
# Otherwise extracts itself then installs the VMIS.
main() {
   local fullpath="$0"
   local help
   local extract

   if [ -z "$VMWARE_SKIP_ARCH_CHECK" -a "`get_arch`" != "$ARCH" ]; then
      echo "This is a $ARCH bundle and does not match that of the current "
      echo "architecture.  Please download the `get_arch` bundle."
      exit 1
   fi

   if [ "$1" = "-h" -o "$1" = "--help" ]; then
      help=$1
      shift
   fi

   if [ "$1" = "-x" -o "$1" = "--extract" ]; then
      extract=$1
      shift
   fi

   if is_relative "$fullpath"; then
      fullpath="$PWD/$fullpath"
   fi

   if [ $UID -eq 0 ] && [ -z "$help" ] && [ -z "$extract" ]; then
      case "$PRODUCT_NAME" in
          vmware-workstation)
              migrate_networks
              uninstall_old_vix "$@"
              uninstall_old "$@"
              ;;
          vmware-player)
              migrate_networks
              uninstall_old "$@"
              ;;
          vmware-server)
              migrate_networks
              uninstall_old "$@"
              ;;
          vmware-vix)
              uninstall_old_vix "$@"
              ;;
          test-component)
              uninstall_bundle /etc/vmware-test -test "$@"
      esac
   fi

   if ! set_lengths "$0"; then
      echo "Unable to extract lengths from bundle."
      exit 1
   fi

   #VMIS_TEMP=/tmp/vmis.IjiJWJ
   VMIS_TEMP=/opt/projects/temp/1/tmp/vmis.IjiJWJ
   #patchelf --set-interpreter /nix/store/rir9pf0kz1mb84x5bd3yr0fx415yy423-glibc-2.33-123/lib64/ld-linux-x86-64.so.2 $VMIS_TEMP/vmis-launcher
   #patchelf --set-interpreter /nix/store/rir9pf0kz1mb84x5bd3yr0fx415yy423-glibc-2.33-123/lib64/ld-linux-x86-64.so.2 $VMIS_TEMP/install/vmware-installer/vmis-launcher

#patchelf --replace-needed libpython2.7.so.1.0 /nix/store/zxrnf05y8h59s5pz5gsjwgr78lb6mm67-python-2.7.18/lib/libpython2.7.so.1.0 /opt/projects/temp/1/tmp/vmis.IjiJWJ/install/vmware-installer/python/lib/lib-dynload/_curses.so
#patchelf --replace-needed libncursesw.so.5 /nix/store/dkq9f62bd884kjm2gmrsdn5s934zr5p5-ncurses-abi5-compat-6.3/lib/libncursesw.so.5 /opt/projects/temp/1/tmp/vmis.IjiJWJ/install/vmware-installer/python/lib/lib-dynload/_curses.so
#patchelf --replace-needed libsqlite3.so.0 /nix/store/l6mx3ksrzf7pnw0jyaalmg6kcwhb5gz3-sqlite-3.36.0/lib/libsqlite3.so.0 /opt/projects/temp/1/tmp/vmis.IjiJWJ/install/vmware-installer/python/lib/lib-dynload/_sqlite3.so

   echo "Patch ELF"
   patchelf --set-interpreter /nix/store/rir9pf0kz1mb84x5bd3yr0fx415yy423-glibc-2.33-123/lib64/ld-linux-x86-64.so.2 $VMIS_TEMP/install/vmware-installer/vmis-launcher
   PYSO=$VMIS_TEMP/install/vmware-installer/python/lib/lib-dynload/
   for so in ${PYSO}/*.so; do
       echo "Patch $so"
       patchelf --replace-needed libpython2.7.so.1.0 /nix/store/zxrnf05y8h59s5pz5gsjwgr78lb6mm67-python-2.7.18/lib/libpython2.7.so.1.0 $so
       patchelf --replace-needed libncursesw.so.5 /nix/store/dkq9f62bd884kjm2gmrsdn5s934zr5p5-ncurses-abi5-compat-6.3/lib/libncursesw.so.5 $so
       patchelf --replace-needed libsqlite3.so.0 /nix/store/l6mx3ksrzf7pnw0jyaalmg6kcwhb5gz3-sqlite-3.36.0/lib/libsqlite3.so.0 $so
       patchelf --replace-needed libz.so.1 /nix/store/9b9ryxskcwh573jwjz6m5l01whkcb39a-zlib-1.2.11/lib/libz.so.1 $so
   done
   echo "Patch done"


   #VMIS_KEEP_TEMP=1 ./VMware-Player-12.5.9-7535481.x86_64.bundle

   #extract_prepayload
   #extract_self
   fullpath=/opt/projects/temp/1/VMware-Player-12.5.9-7535481.x86_64.bundle

   install "$VMIS_TEMP" "$help" "$fullpath" "$extract" "$@"
}

main "$@"

