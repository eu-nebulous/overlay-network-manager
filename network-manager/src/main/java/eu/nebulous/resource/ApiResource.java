package eu.nebulous.resource;

import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import jakarta.ws.rs.Path;

@Singleton
public class ApiResource {
    private final ApplicationNodeResource applicationNodeResource;

    @Inject
    public ApiResource(ApplicationNodeResource applicationNodeResource) {
        this.applicationNodeResource = applicationNodeResource;
    }

    @Path("/node")
    public ApplicationNodeResource getAuthResource() {
        return applicationNodeResource;
    }
}
