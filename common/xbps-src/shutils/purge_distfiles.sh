# Scan srcpkgs/*/template for hashes and distfiles to determine
# obsolete sources/by_sha256 files and their corresponding
# sources/<pkgname>-<version> files that can be purged


purge_distfiles() {
	# Ignore msg_error calls when sourcing templates
	msg_error() {
		:
	}
	if [ -z "$XBPS_SRCDISTDIR" ]; then
		msg_error "The variable \$XBPS_SRCDISTDIR is not set."
		exit 1
	fi
	#
	# Scann all templates for their current distfiles and checksums (hashes)
	#
	declare -A my_hashes
	templates=(srcpkgs/*/template)
	max=${#templates[@]}
	cur=0
	if [ -z "$max" ]; then
		msg_error "No srcpkgs/*/template files found. Wrong working directory?"
		exit 1
	fi
	for template in ${templates[@]}; do
		pkg="$(echo "$template" | cut -d / -f 2)"
		if [ ! -L "srcpkgs/$pkg" ]; then
			unset checksum
			source $template 2>/dev/null
			read -a _my_hashes <<< ${checksum}
			i=0
			while [ -n "${_my_hashes[$i]}" ]; do
				hash="${_my_hashes[$i]}"
				[ -z "${my_hashes[$hash]}" ] && my_hashes[$hash]=$template
				i=$((i + 1))
			done
		fi
		cur=$((cur + 1))
		printf "\rScanning templates  : %3d%% (%d/%d)" $((100*$cur/$max)) $cur $max
	done
	echo
	echo "Number of hashes    : ${#my_hashes[@]}"

	#
	# Collect inodes of all distfiles in $XBPS_SRCDISTDIR
	#
	declare -A inodes
	distfiles=($XBPS_SRCDISTDIR/*/*)
	max=${#distfiles[@]}
	cur=0
	for distfile in ${distfiles[@]}; do
		inode=$(stat "$distfile" --printf "%i")
		if [ -z "${inodes[$inode]}" ]; then
			inodes[$inode]="$distfile"
		else
			inodes[$inode]+="|$distfile"
		fi
		cur=$((cur + 1))
		printf "\rCollecting inodes   : %3d%% (%d/%d)" $((100*$cur/$max)) $cur $max
	done
	echo

	hashes=($XBPS_SRCDISTDIR/by_sha256/*)
	readonly HASHLEN=64
	for file in ${hashes[@]}; do
		hash_distfile=$(basename "$file")
		hash=${hash_distfile:0:$HASHLEN}
		[ -n "${my_hashes[$hash]}" ] && continue
		inode=$(stat "$file" --printf "%i")
		echo "Obsolete $hash (inode: $inode)"
		( IFS="|"; for f in ${inodes[$inode]}; do rm -v "$f"; done )
	done
	echo "Done."
}
