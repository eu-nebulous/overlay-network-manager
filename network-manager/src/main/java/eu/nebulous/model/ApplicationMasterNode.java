package eu.nebulous.model;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.util.Date;

@Entity
@EqualsAndHashCode(callSuper = false)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ApplicationMasterNode extends PanacheEntity {
    private String uuid;

    @Column(name = "publicIp")
    private String publicIp;

    @Column(name = "applicationUUID")
    private String applicationUUID;

    @Column(name = "sshUsername")
    private String sshUsername;

    @Column(length = 5000, name = "openSSLPrivateKey")
    private String openSSLPrivateKey;

    @Column(length = 1000, name = "openSSLPublicKey")
    private String openSSLPublicKey;

    @Column(name = "wireguardPrivateKey")
    private String wireguardPrivateKey;

    @Column(name = "wireguardPublicKey")
    private String wireguardPublicKey;

    @Column(name = "wireguardOverlaySubnet")
    private String wireguardOverlaySubnet;

    @Column(name = "wireguardIp")
    private String wireguardIp;

    @Column(name = "dateCreated")
    private Date dateCreated;
}
