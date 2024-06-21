package eu.nebulous.dto;

public record WireguardPeerDto (
    String wireguardPublicKey,
    String publicIp,
    String wireguardIp
) {}
