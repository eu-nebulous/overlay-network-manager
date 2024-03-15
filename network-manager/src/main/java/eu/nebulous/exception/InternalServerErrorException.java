package eu.nebulous.exception;

import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;

import java.io.Serial;

public class InternalServerErrorException extends WebApplicationException {
    @Serial
    private static final long serialVersionUID = 1L;

    public InternalServerErrorException() {
        this("HTTP 500 - Internal server error. Please contact site admin.");
    }

    public InternalServerErrorException(String message) {
        super(Response.status(Response.Status.INTERNAL_SERVER_ERROR).entity(message).build());
    }
}