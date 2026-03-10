alias bazel='/Users/james/bin/mybazel'

export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home

path+=('/Users/james/bin')
path+=('/Users/james/.local/bin')
path+=('/Users/james/workspace/go/bin')
path+=('/Users/james/go/bin')
path=('/opt/homebrew/bin' $path)
fpath+=('/Users/james/.zfunc')

# GNU getopt for devdock
path=('/opt/homebrew/opt/gnu-getopt/bin' $path)

# LS color
export LSCOLORS=gxfxbEaEBxxEhEhBaDaCaD
alias ls='ls -G -L'
alias ll='ls -l -G -L'

# Gcloud
source '/usr/local/share/google-cloud-sdk/path.zsh.inc'
source '/usr/local/share/google-cloud-sdk/completion.zsh.inc'
export CLOUDSDK_PYTHON_SITEPACKAGES=1
export CLOUDSDK_PYTHON=/Users/james/workspace/scio/python_scio/scio_env/bin/python
export CLOUDSDK_GSUTIL_PYTHON=/Users/james/workspace/scio/python_scio/scio_env/bin/python
export CLOUDSDK_BQ_PYTHON=/Users/james/workspace/scio/python_scio/scio_env/bin/python

# Scio python
source $HOME/workspace/scio/python_scio/scio_env/bin/activate
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
alias scio=/Users/james/workspace/scio/tools/scio.sh

# Clang
export CPLUS_INCLUDE_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1

function ibazel {
    command ibazel -bazel_path=/Users/james/bin/mybazel "$@"
}

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/james/workspace/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/james/workspace/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/james/workspace/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/james/workspace/google-cloud-sdk/completion.zsh.inc'; fi

# fzf
export FZF_CTRL_R_OPTS=$'--bind ctrl-/:toggle-wrap --wrap-sign "\t↳ "'
source <(fzf --zsh)
export PATH="/opt/homebrew/opt/gnu-getopt/bin:$PATH"
alias floo='claude --settings tools/floo/floo-settings.json --append-system-prompt-file tools/floo/floo-append-system-prompt.txt'
eval "$(/Users/james/.local/bin/mise activate zsh)"
