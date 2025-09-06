#!/bin/bash

PKG_DIR="/usr/local/my-pkgmgr/pkgs"
DB_DIR="/usr/local/my-pkgmgr/db"
BUILD_DIR="/usr/local/my-pkgmgr/build"
SRC_DIR="/usr/local/src"

mkdir -p "$DB_DIR" "$BUILD_DIR"

install_pkg() {
    pkg=$1
    recipe="$PKG_DIR/$pkg.sh"

    if [ ! -f "$recipe" ]; then
        echo "❌ Receita $pkg não encontrada!"
        exit 1
    fi

    echo "📦 Instalando $pkg..."
    source "$recipe"

    # Verifica se já está instalado
    if [ -f "$DB_DIR/$pkg.ver" ]; then
        echo "⚠️  $pkg já está instalado (versão $(cat $DB_DIR/$pkg.ver))."
        return
    fi

    # Baixa e compila
    cd "$SRC_DIR"
    wget -q "$SRC_URL" -O "$pkg.tar.gz"
    tar xf "$pkg.tar.gz"
    cd "$SRC_DIR/$SRC_DIRNAME"

    # Compila com prefixo /usr mas "instala" num diretório temporário
    make clean >/dev/null 2>&1
    ./configure --prefix=/usr
    make -j$(nproc)

    DESTDIR="$BUILD_DIR/$pkg" make install

    # Copia arquivos para o sistema
    cp -av "$BUILD_DIR/$pkg"/* /

    # Registra arquivos instalados
    find "$BUILD_DIR/$pkg" -type f | sed "s|$BUILD_DIR/$pkg||" > "$DB_DIR/$pkg.files"
    echo "$VERSION" > "$DB_DIR/$pkg.ver"

    echo "✅ $pkg $VERSION instalado com sucesso!"
}

remove_pkg() {
    pkg=$1
    if [ ! -f "$DB_DIR/$pkg.files" ]; then
        echo "❌ $pkg não está instalado."
        exit 1
    fi

    echo "📦 Removendo $pkg..."

    # Deleta cada arquivo listado
    while read -r file; do
        rm -f "/$file"
    done < "$DB_DIR/$pkg.files"

    # Remove registros
    rm -f "$DB_DIR/$pkg.files" "$DB_DIR/$pkg.ver"

    echo "✅ $pkg removido com sucesso!"
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

case "$1" in
    install) install_pkg "$2" ;;
    remove)  remove_pkg "$2" ;;
    list)    list_pkgs ;;
    *) echo "Uso: $0 {install|remove|list} pacote" ;;
esac
