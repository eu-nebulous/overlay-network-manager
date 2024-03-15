package eu.nebulous.resource;

import eu.nebulous.dto.ApplicationNodeDto;
import eu.nebulous.service.ApplicationNodeService;
import jakarta.inject.Inject;
import jakarta.inject.Singleton;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Singleton
public class ApplicationNodeResource {

    @Inject
    ApplicationNodeService applicationNodeService;

    @POST
    @Path("/create")
    @Tag(name = "Application Node")
    @Consumes(MediaType.APPLICATION_JSON)
    @Operation(summary = "Add Application Node to Application Cluster")
    public Response addApplicationNode(@Valid ApplicationNodeDto applicationNodeDto) {
        // Create Configuration for Application Node
        var logs = applicationNodeService.evaluateNodeCreation(applicationNodeDto);

        return Response.ok(logs).build();
    }

    @DELETE
    @Path("/delete")
    @Tag(name = "Application Node")
    @Consumes(MediaType.APPLICATION_JSON)
    @Operation(summary = "Delete Application Node From Application Cluster")
    public Response deleteApplicationNode(@Valid ApplicationNodeDto applicationNodeDto) {
        // Create Configuration for Application Node
        var logs = applicationNodeService.evaluateNodeDeletion(applicationNodeDto);

        return Response.ok(logs).build();
    }
}
