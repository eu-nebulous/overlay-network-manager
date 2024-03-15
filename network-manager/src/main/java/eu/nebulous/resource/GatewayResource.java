package eu.nebulous.resource;

import jakarta.inject.Inject;
import jakarta.ws.rs.Path;

@Path("/")
public class GatewayResource {
    private final ApiResource apiResource;

    @Inject
    public GatewayResource(ApiResource apiResource) {
        this.apiResource = apiResource;
    }

    @Path("/api/v1")
    public ApiResource getApiResource() {
        return apiResource;
    }
}