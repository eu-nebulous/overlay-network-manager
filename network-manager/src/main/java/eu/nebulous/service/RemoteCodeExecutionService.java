package eu.nebulous.service;

import jakarta.enterprise.context.ApplicationScoped;
import org.apache.sshd.client.SshClient;
import org.apache.sshd.client.channel.ClientChannelEvent;
import org.apache.sshd.common.keyprovider.FileKeyPairProvider;
import org.apache.sshd.scp.client.ScpClientCreator;

import java.io.BufferedWriter;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Paths;
import java.util.Base64;
import java.util.Collections;
import java.util.Date;
import java.util.EnumSet;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

@ApplicationScoped
public class RemoteCodeExecutionService {

    private static final Logger logger = Logger.getLogger(RemoteCodeExecutionService.class.getName());

    public void runCommand(String username, String privateKeyBase64, String host, int port,
                                  long defaultTimeoutSeconds, String command, String password) {

        File privateKeyFile = createTmpFile(privateKeyBase64);

        var client = SshClient.setUpDefaultClient();
        client.start();

        try (var session = client.connect(username, host, port)
            .verify(defaultTimeoutSeconds, TimeUnit.SECONDS).getSession()) {

            if (password != null) {
                session.addPasswordIdentity(password);
            } else {
                var fileKeyPairProvider = new FileKeyPairProvider();
                fileKeyPairProvider.setPaths(Collections.singleton(Paths.get(privateKeyFile.getAbsolutePath())));
                var key = fileKeyPairProvider.loadKeys(null).iterator().next();

                session.addPublicKeyIdentity(key);
            }

            session.auth().verify(defaultTimeoutSeconds, TimeUnit.SECONDS); // Timeout

            try (var responseStream = new ByteArrayOutputStream();
                var channel = session.createExecChannel(command)) {
                channel.setOut(responseStream);

                try {
                    channel.open().verify(defaultTimeoutSeconds, TimeUnit.SECONDS);
                    try (var pipedIn = channel.getInvertedIn()) {
                        pipedIn.write(command.getBytes());
                        pipedIn.flush();
                    }

                    channel.waitFor(EnumSet.of(ClientChannelEvent.CLOSED),
                        TimeUnit.SECONDS.toMillis(defaultTimeoutSeconds));
                    var responseString = responseStream.toString();

                    logger.log(Level.INFO, "Response: {0}", new Object[]{responseString});
                } finally {
                    channel.close(false);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            client.stop();
            privateKeyFile.delete();
        }
    }

    public void scpFile(String username, String host, int port, String privateKeyBase64, long defaultTimeoutSeconds,
                               String localFilePath, String remoteTargetFolder, String password) {

        File privateKeyFile = createTmpFile(privateKeyBase64);

        var client = SshClient.setUpDefaultClient();
        client.start();

        try (var session = client.connect(username, host, port)
            .verify(defaultTimeoutSeconds, TimeUnit.SECONDS).getSession()) {

            if (password != null) {
                session.addPasswordIdentity(password);
            } else {
                var fileKeyPairProvider = new FileKeyPairProvider();
                fileKeyPairProvider.setPaths(Collections.singleton(Paths.get(privateKeyFile.getAbsolutePath())));
                var key = fileKeyPairProvider.loadKeys(null).iterator().next();

                session.addPublicKeyIdentity(key);
            }

            session.auth().verify(defaultTimeoutSeconds, TimeUnit.SECONDS);

            var creator = ScpClientCreator.instance();
            var scpClient = creator.createScpClient(session);

            // To SCP a file to the remote system
            scpClient.upload(localFilePath, "/home/" + username + "/" + remoteTargetFolder);
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            client.stop();
            privateKeyFile.delete();
        }
    }

    private File createTmpFile(String privateKey) {
        try {
            // Create temp file.
            var temp = File.createTempFile("originPK" + UUID.randomUUID(), ".txt");

            // Write to temp file
            var out = new BufferedWriter(new FileWriter(temp));
            var decodedString = new String(Base64.getMimeDecoder().decode(privateKey.getBytes()), StandardCharsets.UTF_8);

            out.write(decodedString);
            out.close();

            return temp;
        } catch (IOException e) {
            logger.log(Level.SEVERE, "{0} -> Problem creating tmp file for Origin Private Key File", new Object[]{new Date()});
            return null;
        }
    }
}
