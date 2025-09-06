#!/bin/bash

PKG_DIR="/usr/local/my-pkgmgr/pkgs"
DB_DIR="/usr/local/my-pkgmgr/db"
BUILD_DIR="/usr/local/my-pkgmgr/build"
SRC_DIR="/usr/local/src"
REPO_URL="https://raw.githubusercontent.com/seuuser/mypkg-repo/main"

mkdir -p "$DB_DIR" "$BUILD_DIR" "$PKG_DIR"

fetch_recipe() {
    pkg=$1
    recipe="$PKG_DIR/$pkg.sh"

    if [ ! -f "$recipe" ]; then
        echo "🌐 Baixando receita $pkg do repositório..."
        curl -s -L "$REPO_URL/$pkg.sh" -o "$recipe" || {
            echo "❌ Não encontrei $pkg no repositório."
            exit 1
        }
    fi
}

install_pkg() {
    pkg=$1
    fetch_recipe "$pkg"
    source "$PKG_DIR/$pkg.sh"

    # Instala dependências
    for dep in ${DEPENDS[@]}; do
        if [ ! -f "$DB_DIR/$dep.ver" ]; then
            echo "➡️ Instalando dependência: $dep"
            $0 install "$dep"
        fi
    done

    # Verifica se já está instalado
    if [ -f "$DB_DIR/$pkg.ver" ]; then
        echo "⚠️  $pkg já está instalado (versão $(cat $DB_DIR/$pkg.ver))."
        return
    fi

    build_and_install "$pkg" "$SRC_URL" "$SRC_DIRNAME" "$VERSION" "${DEPENDS[@]}"
}

build_and_install() {
    pkg=$1
    url=$2
    srcdir=$3
    ver=$4
    shift 4
    deps=("$@")

    echo "📦 Compilando e instalando $pkg $ver..."

    cd "$SRC_DIR"
    wget -q "$url" -O "$pkg.tar.gz"
    tar xf "$pkg.tar.gz"
    cd "$SRC_DIR/$srcdir"

    make clean >/dev/null 2>&1
    ./configure --prefix=/usr
    make -j$(nproc)

    DESTDIR="$BUILD_DIR/$pkg" make install

    cp -av "$BUILD_DIR/$pkg"/* /

    find "$BUILD_DIR/$pkg" -type f | sed "s|$BUILD_DIR/$pkg||" > "$DB_DIR/$pkg.files"
    echo "$ver" > "$DB_DIR/$pkg.ver"
    echo "${deps[@]}" > "$DB_DIR/$pkg.deps"

    echo "✅ $pkg $ver instalado com sucesso!"
}

remove_pkg() {
    pkg=$1
    if [ ! -f "$DB_DIR/$pkg.ver" ]; then
        echo "❌ $pkg não está instalado."
        exit 1
    fi

    for depfile in "$DB_DIR"/*.deps; do
        [ -e "$depfile" ] || continue
        depender=$(basename "$depfile" .deps)
        if grep -qw "$pkg" "$depfile"; then
            echo "❌ Não posso remover $pkg: $depender depende dele."
            exit 1
        fi
    done

    echo "📦 Removendo $pkg..."
    while read -r file; do
        rm -f "/$file"
    done < "$DB_DIR/$pkg.files"

    rm -f "$DB_DIR/$pkg.files" "$DB_DIR/$pkg.ver" "$DB_DIR/$pkg.deps"

    echo "✅ $pkg removido com sucesso!"
}

upgrade_pkg() {
    pkg=$1
    fetch_recipe "$pkg"
    source "$PKG_DIR/$pkg.sh"

    if [ ! -f "$DB_DIR/$pkg.ver" ]; then
        echo "⚠️ $pkg não está instalado. Use 'install'."
        exit 1
    fi

    current=$(cat "$DB_DIR/$pkg.ver")
    if [ "$VERSION" = "$current" ]; then
        echo "✅ $pkg já está na versão $VERSION"
        return
    fi

    echo "⬆️ Atualizando $pkg de $current para $VERSION..."

    rm -f "$DB_DIR/$pkg.files" "$DB_DIR/$pkg.ver"

    build_and_install "$pkg" "$SRC_URL" "$SRC_DIRNAME" "$VERSION" "${DEPENDS[@]}"
}

list_pkgs() {
    echo "📋 Pacotes instalados:"
    for f in "$DB_DIR"/*.ver; do
        [ -e "$f" ] || continue
        pkg=$(basename "$f" .ver)
        ver=$(cat "$f")
        echo " - $pkg ($ver)"
    done
}

info_pkg() {
    pkg=$1
    if [ ! -f "$DB_DIR/$pkg.ver" ]; then
        echo "❌ $pkg não está instalado."
        exit 1
    fi
    echo "📦 Pacote: $pkg"
    echo "   Versão: $(cat $DB_DIR/$pkg.ver)"
    echo "   Depende de: $(cat $DB_DIR/$pkg.deps 2>/dev/null)"
}

case "$1" in
    install) install_pkg "$2" ;;
    remove)  remove_pkg "$2" ;;
    upgrade) upgrade_pkg "$2" ;;
    list)    list_pkgs ;;
    info)    info_pkg "$2" ;;
    *) echo "Uso: $0 {install|remove|upgrade|list|info} pacote" ;;
esac
