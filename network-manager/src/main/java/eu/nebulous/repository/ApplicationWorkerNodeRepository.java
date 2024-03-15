package eu.nebulous.repository;

import eu.nebulous.dto.ApplicationNodeDto;
import eu.nebulous.model.ApplicationMasterNode;
import eu.nebulous.model.ApplicationWorkerNode;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;

@ApplicationScoped
public class ApplicationWorkerNodeRepository implements PanacheRepository<ApplicationWorkerNode> {
    public List<ApplicationWorkerNode> findWorkerNodesByMasterNode(ApplicationMasterNode masterNode){
        return find("applicationMasterNode", masterNode).list();
    }

    public ApplicationWorkerNode findWorkerByPublicIp(ApplicationNodeDto applicationNodeDto){
        return find("publicIp", applicationNodeDto.publicIp()).firstResult();
    }
}
