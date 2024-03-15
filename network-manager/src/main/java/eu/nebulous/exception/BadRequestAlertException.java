package eu.nebulous.exception;

import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;

import java.io.Serial;

import static jakarta.ws.rs.core.Response.Status.BAD_REQUEST;

public class BadRequestAlertException extends WebApplicationException {
    @Serial
    private static final long serialVersionUID = 1L;

    public BadRequestAlertException(String message, String entityName, String errorKey) {
        super(Response.status(BAD_REQUEST).entity(message).header("message", "error." + errorKey).header("params", entityName).build());
    }
}
