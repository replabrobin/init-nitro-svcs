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
	local mt=0 f t name="$1" d="${TOP}/src/${name}"
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
pkgbuild(){
	local dir="$1" name="$(basename $1)" q='"' d='$' fn bn S="" SI="" I="" B="" t=$'\t' n=$'\n'
	for fn in "$TOP/src/$name"/$name.{run,check,setup,finish,conf,install}; do
		if [ -f "$fn" ]; then
			bn="$(basename "$fn")"
			if [ "$bn" = "$name.install" ]; then
				I="install='$name.install'${n}"
			else
				S="${S}${t}${bn}${n}"
				SI="${SI}${t}install -Dm755 ${q}${d}srcdir${q}/${bn} ${q}${d}pkgdir/etc/nitro/sv/${name}/${bn#*.}${q}${n}"
				B="${B}${t}'$(b2sum $fn | cut -d' ' -f1)'${n}"
			fi
		fi
	done
	echo "# Maintainer: replabrobin <replabrobin@gmail.com>
pkgname=${name}-nitro
pkgver='$(pkg-mt "$name")'
pkgrel=1
pkgdesc='nitro service script for ${name}'
arch=('any')
url=${q}https://github.com/replabrobin/init-nitro-svcs${q}
license=('BSD')
depends=('${name}' 'nitro')
#groups=('nitro-galaxy')
provides=('init-${name}')
conflicts=('init-${name}')
${I}source=(
${S%${n}}
	)
${I}b2sums=(
${B%${n}}
	)

package() {
	install -dm755 ${q}${d}pkgdir/etc/nitro/sv/${name}/${q}
${SI%${n}}
}"
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
	for x in $@; do
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
