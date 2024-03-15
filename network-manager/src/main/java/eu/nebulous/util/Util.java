package eu.nebulous.util;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import eu.nebulous.exception.NotFoundAlertException;
import jakarta.enterprise.context.ApplicationScoped;

import java.io.PrintWriter;
import java.io.StringWriter;

@ApplicationScoped
public class Util {
    public String exceptionResponse(Exception e){
        var errors = new StringWriter();
        e.printStackTrace(new PrintWriter(errors));
        return errors.toString();
    }

    public String toString(Object obj) {
        try {
            return new ObjectMapper().writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            throw new NotFoundAlertException(e.toString());
        }
    }
}