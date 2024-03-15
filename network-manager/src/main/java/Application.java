import io.quarkus.runtime.ShutdownEvent;
import io.quarkus.runtime.StartupEvent;
import io.quarkus.runtime.configuration.ProfileManager;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;

import java.time.ZoneId;
import java.util.TimeZone;
import java.util.logging.Level;
import java.util.logging.Logger;

@ApplicationScoped
public class Application {

    private static final Logger logger = Logger.getLogger(Application.class.getName());

    public Application() {
        // Empty Constructor
    }

    void onStart(@Observes StartupEvent ev) {
        logger.info("The application is starting...");
        logger.log(Level.INFO,"Default timezone: {0} with id {1}", new Object[]{TimeZone.getDefault().getDisplayName(), ZoneId.systemDefault()});
        var profile = ProfileManager.getLaunchMode();
        logger.log(Level.INFO,"Running profile: {0}", profile);
    }

    void onStop(@Observes ShutdownEvent ev) {
        logger.info("The application is stopping...");
    }
}
