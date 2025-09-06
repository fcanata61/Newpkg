#!/bin/bash

PKG_DIR="/usr/local/my-pkgmgr/pkgs"
DB_DIR="/usr/local/my-pkgmgr/db"
BUILD_DIR="/usr/local/my-pkgmgr/build"
SRC_DIR="/usr/local/my-pkgmgr/src"
BINPKG_DIR="/usr/local/my-pkgmgr/binpkgs"
REPO_URL="https://raw.githubusercontent.com/seuuser/mypkg-repo/main"

mkdir -p "$DB_DIR" "$BUILD_DIR" "$PKG_DIR" "$SRC_DIR" "$BINPKG_DIR"

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

check_integrity() {
    file=$1
    expected=$2

    echo "🔑 Verificando integridade..."
    actual=$(sha256sum "$file" | awk '{print $1}')

    if [ "$actual" != "$expected" ]; then
        echo "❌ Falha de integridade!"
        echo "   Esperado: $expected"
        echo "   Obtido : $actual"
        exit 1
    fi

    echo "✅ Integridade verificada"
}

build_pkg() {
    pkg=$1
    fetch_recipe "$pkg"
    source "$PKG_DIR/$pkg.sh"

    echo "📦 Compilando $pkg $VERSION..."

    cd "$SRC_DIR"
    wget -q "$SRC_URL" -O "$pkg.tar.gz"

    check_integrity "$pkg.tar.gz" "$SHA256"

    tar xf "$pkg.tar.gz"
    cd "$SRC_DIR/$SRC_DIRNAME"

    make clean >/dev/null 2>&1
    ./configure --prefix=/usr
    make -j$(nproc)

    DESTDIR="$BUILD_DIR/$pkg" fakeroot make install

    pkgfile="$BINPKG_DIR/${pkg}-${VERSION}.pkg.tar.xz"
    tar -C "$BUILD_DIR/$pkg" -cJf "$pkgfile" .

    echo "✅ Pacote binário gerado: $pkgfile"
}

install_pkg() {
    pkg=$1
    fetch_recipe "$pkg"
    source "$PKG_DIR/$pkg.sh"

    # Se existir pacote binário, instala direto
    pkgfile="$BINPKG_DIR/${pkg}-${VERSION}.pkg.tar.xz"
    if [ -f "$pkgfile" ]; then
        echo "📦 Instalando $pkg $VERSION a partir de binário..."
        fakeroot tar -C / -xJf "$pkgfile"

        tar -tJf "$pkgfile" > "$DB_DIR/$pkg.files"
        echo "$VERSION" > "$DB_DIR/$pkg.ver"
        echo "${DEPENDS[@]}" > "$DB_DIR/$pkg.deps"

        echo "✅ $pkg $VERSION instalado com sucesso!"
        return
    fi

    # Senão, compila do zero
    build_pkg "$pkg"
    install_pkg "$pkg"
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

    build_pkg "$pkg"
    install_pkg "$pkg"
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
    build)   build_pkg "$2" ;;
    install) install_pkg "$2" ;;
    remove)  remove_pkg "$2" ;;
    upgrade) upgrade_pkg "$2" ;;
    list)    list_pkgs ;;
    info)    info_pkg "$2" ;;
    *) echo "Uso: $0 {build|install|remove|upgrade|list|info} pacote" ;;
esac
