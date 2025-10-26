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

nitroize(){
	echo "$1" | sed -e's/runit/nitro/g'
}

get-pkgbuild-data(){
	local src="$(cat "${1}/PKGBUILD")" tmp _x
	pkgbuild-value(){
		local s kind="$1" A
		s="$(echo "$src" | sed -n -e'/^'"$kind"'=(.*)/{s/\(([^()]*)\).*/\1/p}')"
		if [ -z "${s}" ]; then
			s="$(echo "$src" | sed -n -e'/^'"$kind"'=/,/.*)/p')"
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
	_pkgbuild-array(){
		local A x kind="$1" filter="$2"
		eval A=\( "$(pkgbuild-value "$kind")" \)
		for x in "${A[@]}"; do
			if [ -n "$filter" ]; then
				x="$($filter "$x")"
			fi
			[ -n "$x" ] && echo "'$x'" || true
		done
	}
	pkgbuild-array(){
		local A
		eval A=\( "$(_pkgbuild-array "$1" "$2")" \)
		if [ -n "$A" ]; then
			local x t=$'\t'
			echo "$1=("
			for x in "${A[@]}"; do
				echo "$t'$x'"
			done
			echo "$t)"
		fi
	}
	inst-sv-names(){
		local n f fn m N i cdst csrc lf=$'\n' tab=$'\t' q='"' d='$'
		local N=$(echo "$src" | sed -n -e'/^\s*_inst_sv\s/{s/^\s*_inst_sv\s*//;s/['$'"'$"'"']//g;p}' | sort -u)
		if [ -n "$N" ]; then
			for n in ${N}; do
				case "$n" in
					(log*|*.log*) continue;;
				esac
				for f in run finish check conf; do
					fn="$1/$n.$f"
					[ ! -f "$fn" ] && continue || true
					cdst="$(nitroize "$n.$f")"
					csrc="$n.$f"
					case "$f" in
						(conf) m="644";i=conf;;
						(*) m="755";i="$cdst";;
					esac
					_CSRC+=("$csrc")
					_CDST+=("$cdst")
					_PBD[itext]="${_PBD[itext]}${tab}install -Dm755 ${q}${d}srcdir${q}/${cdst} ${q}${d}pkgdir/etc/nitro/sv/$n/${i}${q}${lf}"
					_PBD[source]="${_PBD[source]}${tab}${cdst}${lf}"
					_PBD[b2sums]="${_PBD[b2sums]}${tab}'$(b2sum $fn | cut -d' ' -f1)'${lf}"
				done
			done
		else
			#echo "$src" | sed -n -e'/^\s*install\s\s*-Dm/{s/^\s*//;s/\s\s*$//;s/\s\s*/ /g;p}' | sort -u | while read N; do
			N=$(echo "$src" | sed -n -e'/^\s*install\s\s*-Dm/{s/^\s*//;s/\s\s*$//;s/\s\s*/ /g;p}' | cut -d' ' -f3 | sort -u)
			for n in ${N}; do
				n="$(basename "$n")"
				case "$n" in
					(log*.run|*.log.run) continue;;
				esac
				fn="$1/$n"
				[ ! -f "$fn" ] && continue || true
				cdst="$(nitroize "$n")"
				csrc="$n"
				case "$n" in
					(*conf) m="644";i=conf;;
					(*) m="755";i="$cdst";;
				esac
				_CSRC+=("$csrc")
				_CDST+=("$cdst")
				_PBD[itext]="${_PBD[itext]}${tab}install -Dm755 ${q}${d}srcdir${q}/${cdst} ${q}${d}pkgdir/etc/nitro/sv/${_PBD[svcname]}/${i}${q}${lf}"
				_PBD[source]="${_PBD[source]}${tab}${cdst}${lf}"
				_PBD[b2sums]="${_PBD[b2sums]}${tab}'$(b2sum $fn | cut -d' ' -f1)'${lf}"
			done
		fi
	}
	_CSRC=()
	_CDST=()
	_PBD["oname"]="$(basename "$1")"
	_PBD["name"]="$(nitroize "${_PBD[oname]}")"
	_PBD["ver"]="$(echo "$src" | sed -n -e'/^pkgver=/{s/^pkgver=//;p}')"
	_PBD["rel"]="$(echo "$src" | sed -n -e'/^pkgrel=/{s/^pkgrel=//;p}')"
	tmp="$(echo "$src" | sed -n -e'/^install=/{s/install=//;s/['"'"$q]'//g;p}')"
	if [ -n "$tmp" ]; then
		_CSRC+=("$tmp")
		_CDST+=("$(nitroize "$tmp")")
	fi
	_PBD["install"]="$(nitroize "$(echo "$src" | sed -n -e'/^install=/{p}')")"
	_PBD["svcname"]="${_PBD[name]%-nitro}"
	for _x in provides conflicts depends optdepends; do
		_PBD["$_x"]="$(pkgbuild-array "$_x" depends-filter)"
	done
	_PBD["source"]=""
	_PBD["itext"]=""
	_PBD["b2sums"]=""
	inst-sv-names "${sdir}"
}

script-names(){
	local dir="${1%/}" name="$(basename "$1")" cname
	for cname in "$dir"/{"$name","${name%-runit}"} "$dir"/*.{run,check,setup,finish,conf,install}; do
		cname="$(basename "$cname")"
		case "$cname" in
			(log*|*.log.run) ;;
			(*) [ -e "$dir/$cname" ] && echo "$cname";;
		esac
	done | sort -u
}

pkgbuild(){
	local sdir="${1%/}" tdir=${2%/} i q='"' d='$' show="${3:-1}" lf=$'\n'
	declare -A _PBD
	declare -a _CSRC _CDST
	get-pkgbuild-data "$sdir"
	cleandir "$tdir"
	[ "$?" != "0" ] && return 1
	ptext="# Maintainer: replabrobin <replabrobin@gmail.com>
pkgname='${_PBD[name]}'
pkgver='${_PBD[ver]}'
pkgrel='${_PBD[rel]}'
pkgdesc='nitro service script for ${_PBD[svcname]}'
arch=('any')
url=${q}https://github.com/replabrobin/init-nitro-svcs${q}
license=('BSD')
#groups=('nitro-galaxy')
${_PBD[install]}
${_PBD[provides]}
${_PBD[conflicst]}
${_PBD[depends]}
${_PBD[optdepends]}
${I}source=(
${_PBD[source]%${lf}}
	)
${I}b2sums=(
${_PBD[b2sums]%${lf}}
	)
package() {
${_PBD[itext]%${lf}}
}"
	if [ -d "$tdir" ]; then
		xfer(){
			[ -z "$1" ] && return 0 || true
			local sfn="$sdir/$1" dfn
			if [ -f "$sfn" ]; then
				[ -n "$2" ] && dfn="$tdir/$2" || dfn="$tdir/$1"
				cp -p "$sfn" "$dfn"
				sed -i -e's/runit/nitro/g;s/sv check/nitroctl check/g' "$dfn"
			fi
		}
		echo "$ptext" > "$tdir/PKGBUILD"
		xfer "README.md"
		for i in "${!_CSRC[@]}"; do
			xfer "${_CSRC[$i]}" "${_CDST[$i]}"
		done
	fi
	[ "$show" = "1" ] && echo "$ptext"
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
