{ pkgsUnstable_, ... }:
{
  home.packages = with pkgsUnstable_; [
    icu
    dotnet-sdk_9
    vscode-fhs
    nixd # nix language server
    nixfmt-rfc-style
  ];
}
