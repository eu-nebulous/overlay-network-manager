package eu.nebulous.dto;

public record ApplicationNodeDto(
    String publicIp,
    String applicationUUID,
    Boolean isMaster,
    String sshUsername,
    String privateKeyBase64,
    String publicKey,
    String sshPort
) {}
