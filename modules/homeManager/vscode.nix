{ pkgsUnstable_, ... }:
# To use sudo or nix-rebuild use terminal, using this vscode would not allow to run elevated commands?
{
  home.packages = with pkgsUnstable_; [
    icu
    dotnet-sdk_9
    vscode-fhs
    nixd # nix language server
    nixfmt-rfc-style
  ];
}
