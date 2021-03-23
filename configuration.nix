# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  services.grafana.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.useSandbox = true;
  nix.nrBuildUsers = 150;
  nix.maxJobs = 6;
  # make it so nix builds don't compete with user lvl processes
  nix.daemonIONiceLevel = 5;
  nix.daemonNiceLevel = 15;
  nix.trustedUsers = [ "root" "@wheel" "jon" ];

  nix.distributedBuilds = false;
  nix.extraOptions = ''
    show-trace = true
    builders-use-substitutes = true
    experimental-features = nix-command flakes ca-references
  '';
  nix.buildMachines = [ {
    hostName = "server";
    system = "x86_64-linux";
    maxJobs = 50;
    speedFactor = 2;
    supportedFeatures = [ "kvm" "big-parallel" "nixos-test" ];
  }];
  nix.package = pkgs.nixFlakes;
  nix.binaryCaches = [
  ];
  nix.binaryCachePublicKeys = [
  ];

  boot.supportedFilesystems = [ "zfs" "ntfs" ];
  boot.kernelPackages = pkgs.linuxPackages_5_4;
  # needed for detecting cpu temperatures
  boot.kernelModules = [ "kvm" "kvm-intel" "kvm-amd" "k10temp" "fuse" "v4l2loopback-dc" ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.hostName = "jon-desktop";  # Define your hostname.
  # networking.hostId = "b8552dfb";  # Define your hostname.
  #networking.wireless.enable = true;    # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # started in user sessions.
  programs = {
    bash.enableCompletion = true;
    mtr.enable = true;
    ssh.startAgent = false;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryFlavor = "gnome3";
    };
  };

  services.udev.extraRules = let
    dependencies = with pkgs; [ coreutils gnupg gawk gnugrep ];
    clearYubikey = pkgs.writeScript "clear-yubikey" ''
      #!${pkgs.stdenv.shell}
      export PATH=${pkgs.lib.makeBinPath dependencies};
      keygrips=$(
        gpg-connect-agent 'keyinfo --list' /bye 2>/dev/null \
          | grep -v OK \
          | awk '{if ($4 == "T") { print $3 ".key" }}')
      for f in $keygrips; do
        rm -v ~/.gnupg/private-keys-v1.d/$f
      done
      gpg --card-status 2>/dev/null 1>/dev/null || true
    '';
    clearYubikeyUser = pkgs.writeScript "clear-yubikey-user" ''
      #!${pkgs.stdenv.shell}
      ${pkgs.sudo}/bin/sudo -u jon ${clearYubikey}
    '';
  in ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0407", RUN+="${clearYubikeyUser}"
  '';
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];
  environment.systemPackages = with pkgs; [
    paperkey
    yubioath-desktop
    yubikey-manager
  ];
  environment.shellInit = ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent /bye
    export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
  '';
  services.gnome3.gnome-keyring.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.yubikey-agent.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.avahi.enable = true;
  #services.avahi.nssmdns = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    layout = "us";
    videoDrivers = [ "nvidia" ];
    displayManager.lightdm.enable = true;
    #desktopManager.plasma5.enable = true;
    displayManager.lightdm.background = pkgs.nixos-artwork.wallpapers.nineish-dark-gray.gnomeFilePath; # wallpaper-nixos;
    windowManager.i3.enable = true;
    # have i3 open terminology instead of default xterm
  };

  services.gnome3.at-spi2-core.enable = true;
  services.dbus.packages = with pkgs; [ gnome3.dconf gcr ];
  #services.neo4j.enable = true;
  #services.neo4j.https.enable = false;
  #services.neo4j.bolt.enable = true;
  #services.neo4j.bolt.tlsLevel = "DISABLED";

  # chromium
  services.upower.enable = true;

  # Enable touchpad support.
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.jon = {
    description = "Jon Ringer";
    home = "/home/jon/";
    isNormalUser = true;
    shell = pkgs.bash;

    extraGroups = ["wheel" "networkmanager" "docker" "plex" ];
  };

  # for steam
  programs.steam.enable = true;
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;

  # discord
  hardware.pulseaudio = {
    support32Bit = true;
    enable = true;
  };

  # Fix for some intel sound cards, otherwise quality is impaired
  # sound.extraConfig = ''
  #   options snd-hda-intel vid=8086 pid=8ca snoop=0
  # '';

  fonts = {
    #fontDir.enable = true;
    fonts = with pkgs; [
      corefonts
      dejavu_fonts
      freefont_ttf
      google-fonts
      inconsolata
      liberation_ttf
      ubuntu_font_family
    ];
  };

  virtualisation.docker.enable = true;
  virtualisation.virtualbox.host.enable = true;
  virtualisation.libvirtd.enable = true;

  security.pam.loginLimits = [
    { domain = "*";
      type = "*";
      item = "nofile";
      value = "65536";
    }
  ];
  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?
  system.autoUpgrade.enable = true;
}
