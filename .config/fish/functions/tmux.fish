function tmux-update
    if test (count $argv) -eq 0
        echo "Installing and updating Tmux plugins..."
        ~/.tmux/plugins/tpm/bin/install_plugins
        ~/.tmux/plugins/tpm/bin/update_plugins all
    end

    command tmux -u $argv
end
