package eu.nebulous.service;

import eu.nebulous.dto.LogDto;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.Date;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

@ApplicationScoped
public class LogService {
    private static final Logger logger = Logger.getLogger(LogService.class.getName());

    public void log(List<LogDto> logList, Level logLevel, String title, String message) {
        var date = new Date();

        // Add log events to logList
        logList.add(new LogDto(date, logLevel, title, message));

        // Log events
        logger.log(logLevel, "{0}: {1}", new Object[]{date, message});
    }
}
