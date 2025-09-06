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

    source "$recipe"

    # Instala dependências primeiro
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

    echo "📦 Instalando $pkg..."

    # Baixa e compila
    cd "$SRC_DIR"
    wget -q "$SRC_URL" -O "$pkg.tar.gz"
    tar xf "$pkg.tar.gz"
    cd "$SRC_DIR/$SRC_DIRNAME"

    make clean >/dev/null 2>&1
    ./configure --prefix=/usr
    make -j$(nproc)

    DESTDIR="$BUILD_DIR/$pkg" make install

    # Copia arquivos para o sistema
    cp -av "$BUILD_DIR/$pkg"/* /

    # Registra arquivos e dependências
    find "$BUILD_DIR/$pkg" -type f | sed "s|$BUILD_DIR/$pkg||" > "$DB_DIR/$pkg.files"
    echo "$VERSION" > "$DB_DIR/$pkg.ver"
    echo "${DEPENDS[@]}" > "$DB_DIR/$pkg.deps"

    echo "✅ $pkg $VERSION instalado com sucesso!"
}

remove_pkg() {
    pkg=$1

    if [ ! -f "$DB_DIR/$pkg.ver" ]; then
        echo "❌ $pkg não está instalado."
        exit 1
    fi

    # Verifica se outro pacote depende dele
    for depfile in "$DB_DIR"/*.deps; do
        [ -e "$depfile" ] || continue
        depender=$(basename "$depfile" .deps)
        if grep -qw "$pkg" "$depfile"; then
            echo "❌ Não posso remover $pkg: $depender depende dele."
            exit 1
        fi
    done

    echo "📦 Removendo $pkg..."

    # Apaga arquivos
    while read -r file; do
        rm -f "/$file"
    done < "$DB_DIR/$pkg.files"

    # Remove registros
    rm -f "$DB_DIR/$pkg.files" "$DB_DIR/$pkg.ver" "$DB_DIR/$pkg.deps"

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
    list)    list_pkgs ;;
    info)    info_pkg "$2" ;;
    *) echo "Uso: $0 {install|remove|list|info} pacote" ;;
esac
