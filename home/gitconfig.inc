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

    # Too late, these nonsensical names are in muscle memory
    up = pull
    lol =  log --decorate --oneline
    lolg = log --decorate --oneline --graph
    lola = log --decorate --oneline --graph --all

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

