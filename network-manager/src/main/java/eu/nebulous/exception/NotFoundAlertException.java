package eu.nebulous.exception;

import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;

import java.io.Serial;

import static jakarta.ws.rs.core.Response.Status.NOT_FOUND;

public class NotFoundAlertException extends WebApplicationException {
    @Serial
    private static final long serialVersionUID = 1L;

    public NotFoundAlertException(String entityName) {
        super(Response.status(NOT_FOUND).entity("Entity "  + entityName + "was not found")
                .header("message", "error." + "notfound")
                .header("params", entityName).build());
    }
}
