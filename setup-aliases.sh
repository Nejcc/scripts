#!/bin/bash

# Create custom aliases file
cat << 'EOF' > ~/.custom_aliases
# Custom Aliases
alias ll='ls -la'
alias nah='git reset --hard HEAD'
alias pas='php artisan serve'
alias 'pas --port=8000'='php artisan serve --port=8000'
EOF

# Add source command to ~/.bashrc if not already present
if ! grep -q "source ~/.custom_aliases" ~/.bashrc; then
    echo -e "\n# Include custom aliases\nif [ -f ~/.custom_aliases ]; then\n    . ~/.custom_aliases\nfi" >> ~/.bashrc
fi

# Reload ~/.bashrc to apply changes
source ~/.bashrc

echo "Custom aliases added and ~/.bashrc updated to include them."
