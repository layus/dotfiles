[color]
    ui = auto

[color "diff"]
    oldMoved = magenta
    oldMovedAlternative = blue
    oldMovedDim = faint
    oldMovedAlternativeDim = faint italic
    newMoved = cyan
    newMovedAlternative = yellow
    newMovedDim = faint
    newMovedAlternativeDim = faint italic

[push]
    default = simple
    autoSetupRemote = true

[diff]
    compactionHeuristic = true

[alias]
    st = status -s
    ci = commit
    br = branch
    c = checkout
    df = diff
    lg = log -p
    ign = ls-files -o -i --exclude-standard
    up = !eval $(keychain --eval --agents ssh -Q $HOME/.ssh/dark-vador_rsa) && git pull
    pu = !eval $(keychain --eval --agents ssh -Q $HOME/.ssh/dark-vador_rsa) && git push
    fetch = !eval $(keychain --eval --agents ssh -Q $HOME/.ssh/dark-vador_rsa) && git push
    dlog = log --decorate --oneline
    glog = log --graph --oneline --decorate
    gloga = log --graph --oneline --decorate --all

    # old aliases (name is meaningless...)
    lola = log --graph --decorate --oneline --all
    lolg = log --graph --oneline --decorate
    lol = log --decorate --oneline


[rebase]
    autosquash = true

[pull]
    ff = only

[init]
    defaultBranch = main

[filter "lfs"]
    process = git-lfs filter-process
    clean = git-lfs clean -- %f
    smudge = git-lfs smudge -- %f
    required = true

