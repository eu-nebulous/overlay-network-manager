package eu.nebulous.repository;

import eu.nebulous.model.WireguardNode;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;

@ApplicationScoped
public class WireguardNodeRepository implements PanacheRepository<WireguardNode> {

    public WireguardNode fetchNodeByWireguardIp(String wireguardIp) {
        return find("wireguardIp = ?1", wireguardIp).firstResult();
    }

    public List<WireguardNode> fetchNodeListByApplicationUUID(String applicationUUID) {
        return find("applicationUUID = ?1", applicationUUID).list();
    }

    public WireguardNode findByWireguardNodeIp(String wireguardNodeIp){
        return find("wireguardIp", wireguardNodeIp).firstResult();
    }

    public WireguardNode findByWireguardNodeIpAndApplicationUUID(String wireguardNodeIp, String applicationUUID){
        return find("wireguardIp = ?1 and applicationUUID = ?2", wireguardNodeIp, applicationUUID).firstResult();
    }
}
