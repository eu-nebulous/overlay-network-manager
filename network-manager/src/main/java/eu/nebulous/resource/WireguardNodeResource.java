package eu.nebulous.resource;

import eu.nebulous.dto.WireguardNodeDto;
import eu.nebulous.service.WireguardNodeService;
import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Singleton
@Tag(name = "Wireguard Node")
public class WireguardNodeResource {

    @Inject
    WireguardNodeService wireguardNodeService;

    @GET
    @Path("/peers/{wireguardIp}/{applicationUUID}")
    @Consumes(MediaType.APPLICATION_JSON)
    @Operation(summary = "Fetch node's peers by Application UUID")
    public Response fetchNodePeersByApplicationUUID(@PathParam("wireguardIp") String wireguardIp,
                                                    @PathParam("applicationUUID") String applicationUUID) {
        // Create Configuration for Wireguard Node
        var logs = wireguardNodeService.fetchNodeListByApplicationUUIDAndWireguardIp(wireguardIp, applicationUUID);

        return Response.ok(logs).build();
    }

    @POST
    @Path("/create")
    @Consumes(MediaType.APPLICATION_JSON)
    @Operation(summary = "Add Wireguard Node to Application Cluster")
    public Response registerWireguardNode(@Valid WireguardNodeDto wireguardNodeDto) {
        // Create Configuration for Wireguard Node
        var logs = wireguardNodeService.registerWireguardNode(wireguardNodeDto);

        return Response.ok(logs).build();
    }

    @DELETE
    @Path("/delete/{wireguardNodeIp}/{applicationUUID}")
    @Consumes(MediaType.APPLICATION_JSON)
    @Operation(summary = "Delete Wireguard Node From Application Cluster")
    public Response deregisterWireguardNode(@PathParam("wireguardNodeIp") String wireguardNodeIp,
                                            @PathParam("applicationUUID") String applicationUUID) {
        // Delete Configuration for Wireguard Node
        var logs = wireguardNodeService.deregisterWireguardNode(wireguardNodeIp, applicationUUID);

        return Response.ok(logs).build();
    }
}
