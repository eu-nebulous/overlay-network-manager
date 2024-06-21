package eu.nebulous.dto;

public record WireguardNodeDto(
    String publicIp,
    String applicationUUID,
    String sshUsername,
    String privateKeyBase64,
    String publicKey,
    String sshPort
) {}
