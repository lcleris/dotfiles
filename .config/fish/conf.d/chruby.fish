# Active chruby via bass pour Fish
if test -f /opt/homebrew/opt/chruby/share/chruby/chruby.sh
    bass source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
end

if test -f /opt/homebrew/opt/chruby/share/chruby/auto.sh
    bass source /opt/homebrew/opt/chruby/share/chruby/auto.sh
end
