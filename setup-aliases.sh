#!/bin/bash

# Create custom aliases file
cat << 'EOF' > ~/.custom_aliases
# Custom Aliases
alias ll='ls -la'
alias cls='clear'
alias nah='git reset --hard HEAD'
alias pas='php artisan serve'
alias 'pas --port=8000'='php artisan serve --port=8000'
EOF

# Determine the shell and the appropriate rc file
if [ "$SHELL" = "/bin/bash" ]; then
    RC_FILE=~/.bashrc
elif [ "$SHELL" = "/bin/zsh" ]; then
    RC_FILE=~/.zshrc
else
    echo "Unsupported shell: $SHELL"
    exit 1
fi

# Add source command to the rc file if not already present
if ! grep -q "source ~/.custom_aliases" "$RC_FILE"; then
    echo -e "\n# Include custom aliases\nif [ -f ~/.custom_aliases ]; then\n    . ~/.custom_aliases\nfi" >> "$RC_FILE"
fi

# Reload the rc file to apply changes
source "$RC_FILE"

echo "Custom aliases added and $RC_FILE updated to include them."
