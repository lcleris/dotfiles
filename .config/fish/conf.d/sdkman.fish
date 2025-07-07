set -gx SDKMAN_DIR "$HOME/.sdkman"

if test -s "$HOME/.sdkman/bin/sdkman-init.sh"
    bass source $HOME/.sdkman/bin/sdkman-init.sh
end
