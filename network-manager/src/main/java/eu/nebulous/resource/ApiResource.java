package eu.nebulous.resource;

import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import jakarta.ws.rs.Path;

@Singleton
public class ApiResource {
    private final WireguardNodeResource wireguardNodeResource;

    @Inject
    public ApiResource(WireguardNodeResource wireguardNodeResource) {
        this.wireguardNodeResource = wireguardNodeResource;
    }

    @Path("/node")
    public WireguardNodeResource getAuthResource() {
        return wireguardNodeResource;
    }
}
