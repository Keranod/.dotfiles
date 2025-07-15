{ pkgs, ... }:

{
  users.users.keranod = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];  # Allow sudo
    home = "/home/keranod";
    shell = pkgs.bash;
    initialPassword = "12345";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCNv6yMVGqryHVhAF20x+xFgZ5TkbipDWfNccsQIDnaXTmgLMGJE4GL4PmlINW90XULwm/SAVtjbPFCQmXfFa3NUuroxWrWtnoAAktQu1Vfba4kJPzuPB5mVGePvoKNX/jdKI36mdpcE2z7HZ3V0wzS5h0wOoUd58XgR4c+yo6gZ3GQ59VTYw6iPavXwEs7JbpYlLLZrIVFl3+Q/+YkSjL5DJmScfo4Ql7NvWWEg/bYSwBa2dMlnk0S+W81aekqpK3/bL4RlUFtf5fTaTyrhp3UesTlaex5QzYcjfLpeaChNCN1ZkvTcxYpiQmXD6A5Ou2CyU+wvm4ZPXf2P9aX/HvV1+dMBg21x7bpLg07Jv6g9uxlSxqrQgi+TE5m8exOTj9DiiA7fHOsZCIxnkhh72679Lk/NpgBtw6cJSG9NIizV+oLJlwadS6/tfOdZRYgPCNqFa+mga+7Lqn53tHIedBv+Bx22twJi/jHXX+L5QXyotcTamBxn5egkluZx4CSTw00eFiM1eQnJzyZYV9xS3yGSpVUb0uhqxJpBNF4a0GRFgAdzdx6trzCGfJBgBj5maXhDNL0jXpRRbWxcGZeBqsvErmGnK+PneQXvAPgDvIdsVdmAaCPwiXnzGsQlgsAxbX/f9rPqlAxaPatIg36n1FApDrl/BDY7A+tMzgNOH/c6w== konrad.konkel@wp.pl"
    ];
  };

  users.users.root = {
    initialPassword = "12345";
  };
}
