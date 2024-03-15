package eu.nebulous.repository;

import eu.nebulous.model.ApplicationMasterNode;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class ApplicationMasterNodeRepository implements PanacheRepository<ApplicationMasterNode> {

    public ApplicationMasterNode findByApplicationUUID(String applicationUUID){
        return find("applicationUUID", applicationUUID).firstResult();
    }
}
