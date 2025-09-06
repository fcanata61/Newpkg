#!/bin/bash

PKG_DIR="/usr/local/my-pkgmgr/pkgs"
DB_DIR="/usr/local/my-pkgmgr/db"
SRC_DIR="/usr/local/src"

mkdir -p "$DB_DIR"

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
    if [ -f "$DB_DIR/$pkg" ]; then
        echo "⚠️  $pkg já está instalado."
        return
    fi

    # Baixa e compila
    cd "$SRC_DIR"
    wget "$SRC_URL" -O "$pkg.tar.gz"
    tar xf "$pkg.tar.gz"
    cd "$SRC_DIR/$SRC_DIRNAME"

    ./configure --prefix=/usr
    make
    make install

    echo "$VERSION" > "$DB_DIR/$pkg"
    echo "✅ $pkg $VERSION instalado com sucesso!"
}

remove_pkg() {
    pkg=$1
    if [ ! -f "$DB_DIR/$pkg" ]; then
        echo "❌ $pkg não está instalado."
        exit 1
    fi

    echo "⚠️ Remoção simples: não sabe quais arquivos deletar!"
    echo "   (isso teria que ser registrado na instalação)"
    rm -f "$DB_DIR/$pkg"
    echo "✅ $pkg removido do banco de dados."
}

list_pkgs() {
    echo "📋 Pacotes instalados:"
    for f in "$DB_DIR"/*; do
        [ -e "$f" ] || continue
        pkg=$(basename "$f")
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
