yesans(){
	local ans
	while true; do
		read -p "$1 (yes/no):" ans
		case "$ans" in
			(yes|y) return 0;;
			(no|n) return 1;;
			(*) echo "please enter yes or no"
				;;
		esac
	done
}
cleandir(){
	local d="$1"
	if [ -n "$d" ]; then
		if [ -d "$d" ]; then
			if [ -n "$(ls -A "${d}")" ]; then
   				echo "directory '$d' is not empty!"
				if yesans "OK to clean?"; then
					rm -rf "$d"/*
					return 0
				fi
				return 1
			fi
		elif yesans "OK to mkdir -p '$d'?"; then
			mkdir -p "$d" && return 0 || true
   			echo "!!!!! cannot make directory '$d'!"
			return 2
		fi
	fi
}
pkg-names(){
	local d
	for d in "$TOP/src/"*; do
		echo "$(basename "${d}")"
	done | sort
}
pkg-ver(){
	local f="${TOP}/src/${1}/PKGBUILD"
	[ -f "${f}" ] && sed -n -e'/^pkgver=/{s/^pkgver=//;p}' "${f}" || true
}
pkg-src(){
	local s f="${TOP}/src/${1}/PKGBUILD"
	if [ -f "${f}" ]; then
		s="$(sed -n -e'/^source=(.*)/{s/\(([^()]*)\).*/\1/p}' "${f}")"
		if [ -z "${s}" ]; then
			s="$(sed -n -e'/^source=/,/.*)/p' "${f}")"
		fi
		if [ -n "$s" ]; then
			(
			eval "$s"
			echo "${source[@]}"
			)
		fi
	fi
}
pkg-mt(){
	local mt=0 f t d="$1" name="$(basename "$1")"
	for fn in "$TOP/src/$name"/{$name.{run,check,setup,finish,install,hook,conf},PKGBUILD}; do
		t="$(stat -c'%Y' "${d}/${f}")"
		[ "$t" -gt "$mt" ] && mt="$t" || true
	done
	[ "$mt" != 0 ] && echo "$(date -d@${mt} +%Y%m%d)"
}

pkg-info(){
	for p in $(pkg-names); do
		ver="$(pkg-ver "${p}")"
		src="$(pkg-src "${p}")"
		if [ -z "$ver" -o -z "$src" ]; then
				msg="unready"
		else
				mt="$(pkg-mt "${p}")"
			if [ "$mt" != "$ver" ]; then
					msg="rebuild"
			else
					msg="unchanged"
			fi
		fi
		echo "${status} ${p} ${src} ${mt}"
	done
}
_pkgbuild-array(){
	local A x pkgbuild="$1" kind="$2" filter="$3"
	eval A=\( "$(pkgbuild-value "$pkgbuild" "$kind")" \)
	for x in "${A[@]}"; do
		if [ -n "$filter" ]; then
			x="$($filter "$x")"
		fi
		[ -n "$x" ] && echo "'$x'" || true
	done
}
pkgbuild-array(){
	local A
	eval A=\( "$(_pkgbuild-array "$1" "$2" "$3")" \)
	if [ -n "$A" ]; then
		local x t=$'\t'
		echo "$2=("
		for x in "${A[@]}"; do
			echo "$t'$x'"
		done
		echo "$t)"
	fi
}
pkgbuild(){
	local dir="$1" name="$(basename "$1")" q='"' d='$' tdir="$2" show="${3:-1}"
	cleandir "$tdir"
	[ "$?" != "0" ] && return 1
	local fn bn S="" SI="" I="" B="" t=$'\t' n=$'\n' A iname sname
	local pkgbfn="$dir/PKGBUILD" ptext rname="${name%-runit}"
	for fn in "$dir/"{$rname,$name}{,.{run,check,setup,finish,conf,install}}; do
		if [ -f "$fn" ]; then
			bn="$(basename "$fn")"
			[ "$bn" = "$rname" -o "$bn" = "$name" ] && iname=run || iname="${bn#*.}"
			if [ "$bn" = "$name.install" -o "$bn" = "$rname.install" ]; then
				sname="$bn"
				iname="$rname.install"
				I="install='$iname'${n}"
			else
				sname="$bn"
				S="${S}${t}${iname}${n}"
				SI="${SI}${t}install -Dm755 ${q}${d}srcdir${q}/${iname} ${q}${d}pkgdir/etc/nitro/sv/${rname}/${iname}${q}${n}"
				B="${B}${t}'$(b2sum $fn | cut -d' ' -f1)'${n}"
			fi
			if [ -d "$tdir" ]; then
				cp "$dir/$sname" "$tdir/$iname"
			fi
		fi
	done
	ptext="# Maintainer: replabrobin <replabrobin@gmail.com>
pkgname='$(echo ${name}| sed -e's/-runit/-nitro/')'
pkgver='$(pkg-mt "$dir")'
pkgrel=1
pkgdesc='nitro service script for ${name}'
arch=('any')
url=${q}https://github.com/replabrobin/init-nitro-svcs${q}
license=('BSD')
#groups=('nitro-galaxy')
$(pkgbuild-array "$pkgbfn" provides depends-filter)
$(pkgbuild-array "$pkgbfn" conflicts depends-filter)
$(pkgbuild-array "$pkgbfn" depends depends-filter)
$(pkgbuild-array "$pkgbfn" optdepends depends-filter)
${I}source=(
${S%${n}}
	)
${I}b2sums=(
${B%${n}}
	)

package() {
	install -dm755 ${q}${d}pkgdir/etc/nitro/sv/${rname}/${q}
${SI%${n}}
}"
	if [ -d "$tdir" ]; then
		echo "$ptext" > "$tdir/PKGBUILD"
	fi
	[ "$show" = "1" ] && echo "$ptext"
}

pkgbuild-value(){
	local s f="$1" kind="$2" A
	[ ! -f "$f" -o -z "$kind" ] && echo "!!!!! pkgbuild-value <PKGBUILD> <kind>" && exit 1
	s="$(sed -n -e'/^'"$kind"'=(.*)/{s/\(([^()]*)\).*/\1/p}' "$f")"
	if [ -z "${s}" ]; then
		s="$(sed -n -e'/^'"$kind"'=/,/.*)/p' "$f")"
	fi
	if [ -n "$s" ]; then
		(
		eval "$s"
		eval A=\( \"\${${kind}[@]}\" \)
		for s in "${A[@]}"; do echo "'$s'"; done
		)
	fi
}

depends-filter(){
	local x
	for x in "$@"; do
		case "$x" in
			(socklog|syslog-ng|runit-rc)
				;;
			(runit) echo nitro
				;;
			(*) echo "$x"
				;;
		esac
	done | sed -e's/runit/nitro/g'
}

runit-gitea-list(){
	for i in {1..12};do
		curl -s "https://gitea.artixlinux.org/packages?page=$i&q=-runit&sort=recentupdate"
	done | sed -n -e'/<a class="text primary name"/{s/^[^>]*>//;s/<.*$//;p}'
}

conversion-list(){
	local giteadir="$1"
	for x in "$giteadir"/*; do
		case "$x" in
			(syslog-ng-runit|sshdguard-runit)
				;;
			(*) echo "$x"
				;;
		esac
	done
}
