if [ "$1" == "-f" ] || [ ! -f ~/.config/chezmoi/chezmoi.json  ]; then
    echo "Let's configure your git"
    echo "I need your full name and email address, so git will save this information in every commit you make"
    echo "What is your full name?"
    read name
    echo "What is your email address?"
    read email
    mkdir -p ~/.config/chezmoi
    cat << EOF > ~/.config/chezmoi/chezmoi.json
    {
        "data": {
            "git": {
                "name": "$name",
                "email": "$email"
            }
        }
    }
EOF
    chezmoi -v apply
fi