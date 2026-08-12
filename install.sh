#!/bin/sh

set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DOTS_DIR="$SCRIPT_DIR/dots"

PACMAN_PACKAGES="
git
eza
fish
ghostty
hypridle
hyprland
hyprlauncher
hyprpicker
hyprpolkitagent
hyprshot
hyprshutdown
hyprsunset
matugen
neovim
noto-fonts
noto-fonts-cjk
noto-fonts-emoji
ttf-dejavu
ttf-jetbrains-mono-nerd
ttf-liberation
uwsm
yazi
stow
"

AUR_PACKAGES="
quickshell
"

install_missing_packages() {
    installer="$1"
    packages="$2"

    set --
    for package in $packages; do
        if pacman -Qq "$package" >/dev/null 2>&1; then
            echo "Skipping already installed package: $package"
        else
            set -- "$@" "$package"
        fi
    done

    if [ "$#" -eq 0 ]; then
        echo "All packages are already installed."
        return
    fi

    if [ "$installer" = "pacman" ]; then
        sudo pacman -S --needed --noconfirm "$@"
    else
        paru -S --needed --noconfirm "$@"
    fi
}

remove_stow_conflicts() {
    package_dir="$1"
    target_dir="$2"

    find "$package_dir" -mindepth 1 -print | while IFS= read -r source_path; do
        relative_path="${source_path#"$package_dir"/}"
        target_path="$target_dir/$relative_path"

        if [ ! -L "$source_path" ] && [ -d "$source_path" ]; then
            if [ -L "$target_path" ]; then
                echo "Removing conflicting link: $target_path"
                unlink "$target_path"
            elif [ -f "$target_path" ]; then
                echo "Removing conflicting file: $target_path"
                rm -f -- "$target_path"
            fi
        elif [ -L "$target_path" ]; then
            echo "Removing conflicting link: $target_path"
            unlink "$target_path"
        elif [ -f "$target_path" ]; then
            echo "Removing conflicting file: $target_path"
            rm -f -- "$target_path"
        elif [ -e "$target_path" ]; then
            echo "Cannot replace directory or special file: $target_path" >&2
            exit 1
        fi
    done
}

echo "Installing repository packages..."
install_missing_packages pacman "$PACMAN_PACKAGES"

if ! command -v paru >/dev/null 2>&1; then
    echo "Installing paru..."

    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru-bin.git "$tmpdir/paru-bin"

    (
        cd "$tmpdir/paru-bin"
        makepkg -si --noconfirm
    )

    rm -rf "$tmpdir"
fi

echo "Installing AUR packages..."
install_missing_packages paru "$AUR_PACKAGES"

echo "Done."

echo "Installing hyprland depends"
hyprpm add https://github.com/hyprnux/hyprglass || true
hyprpm enable hyprglass || true
hyprpm add https://github.com/sandwichfarm/hyprexpo
hyprpm enable hyprexpo || true

echo "Replacing conflicting config files and links..."
remove_stow_conflicts "$DOTS_DIR" "$HOME"

echo "Creating config links..."
stow --restow --dir="$SCRIPT_DIR" --target="$HOME" dots
