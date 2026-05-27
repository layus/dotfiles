remote_host=""
folder=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--remote)
      remote_host="$2"
      shift 2
      ;;
    -h|--help)
      cat >&2 <<'EOF'
Usage: windsurf [OPTIONS] FOLDER
       windsurf -r|--remote HOST FOLDER

Arguments:
  FOLDER              Local or remote folder path

Options:
  -r, --remote HOST   Connect to remote host
  -h, --help          Show this help message
EOF
      exit 0
      ;;
    *)
      folder="$1"
      shift
      ;;
  esac
done

if [[ -z "$folder" ]]; then
  echo "Error: FOLDER argument is required" >&2
  windsurf --help
  exit 1
fi

# If no remote specified, work locally
if [[ -z "$remote_host" ]]; then
  echo "Opening local folder: $folder" >&2
  NIXPKGS_ALLOW_UNFREE=1 nix run \
    github:NixOS/nixpkgs#windsurf \
    --impure \
    --tarball-ttl 86400 \
    -- "$folder"
else
  # Construct the SSH remote URI
  encoded_host=$(echo -n "{\"hostName\":\"$remote_host\"}" | xxd -p | tr -d '\n')
  remote_url="ssh-remote%2B${encoded_host}${folder}"

  echo "Connecting to: $remote_url" >&2

  # Run windsurf from nixpkgs (cache flake for 24 hours)
  NIXPKGS_ALLOW_UNFREE=1 nix run \
    github:NixOS/nixpkgs#windsurf \
    --impure \
    --tarball-ttl 86400 \
    -- --folder-uri "vscode-remote://$remote_url"
fi
