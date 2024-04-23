package eu.nebulous.service;

import eu.nebulous.dto.LogDto;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
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
import java.util.EnumSet;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;

@ApplicationScoped
public class RemoteCodeExecutionService {
    @Inject
    LogService logService;

    private static final String WG = "WG";

    public void runCommand(List<LogDto> logList, String username, String privateKeyBase64, String host, int port,
                           long defaultTimeoutSeconds, String command, String password) {

        File privateKeyFile = createTmpFile(logList, host, privateKeyBase64);

        logService.log(logList, Level.INFO, WG, "HOST: " + host + ". Setting up SSH Client to SSH. Command: " + command);

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
            logService.log(logList, Level.INFO, WG, "HOST: " + host + ". Authenticating Session");

            try (var responseStream = new ByteArrayOutputStream();
                var channel = session.createExecChannel(command)) {
                channel.setOut(responseStream);

                try {
                    channel.open().verify(defaultTimeoutSeconds, TimeUnit.SECONDS);
                    try (var pipedIn = channel.getInvertedIn()) {
                        pipedIn.write(command.getBytes());
                        pipedIn.flush();
                    }

                    logService.log(logList, Level.INFO, WG, "HOST: " + host + ". Opening SSH Channel");

                    channel.waitFor(EnumSet.of(ClientChannelEvent.CLOSED),
                        TimeUnit.SECONDS.toMillis(defaultTimeoutSeconds));
                    var responseString = responseStream.toString();

                    logService.log(logList, Level.INFO, WG, "HOST: " + host + ". SSH Channel Response: "
                        + responseString);
                } finally {
                    channel.close(false);
                }
            }
        } catch (Exception e) {
            logService.log(logList, Level.SEVERE, WG, "SSH Channel Error from Host: " + host + ": "
                + e.getMessage());
        } finally {
            client.stop();
            privateKeyFile.delete();
        }
    }

    public void scpFile(List<LogDto> logList, String username, String host, int port, String privateKeyBase64, long defaultTimeoutSeconds,
                               String localFilePath, String remoteTargetFolder, String password) {

        File privateKeyFile = createTmpFile(logList, host, privateKeyBase64);

        logService.log(logList, Level.INFO, WG, "HOST: " + host + ". Setting up SSH Client to SSH.");

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
            logService.log(logList, Level.INFO, WG, "HOST: " + host + ". Authenticating Session");

            var creator = ScpClientCreator.instance();
            var scpClient = creator.createScpClient(session);

            logService.log(logList, Level.INFO, WG, "HOST: " + host + ". Uploading " + localFilePath +
                "to /home/" + username + "/" + remoteTargetFolder);
            // To SCP a file to the remote system
            scpClient.upload(localFilePath, "/home/" + username + "/" + remoteTargetFolder);
        } catch (IOException e) {
            logService.log(logList, Level.SEVERE, WG, "SSH Channel Error from Host: " + host + ": "
                + e.getMessage());
        } finally {
            client.stop();
            privateKeyFile.delete();
        }
    }

    private File createTmpFile(List<LogDto> logList, String host, String privateKey) {
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
            logService.log(logList, Level.SEVERE, WG, "HOST: " + host + "Problem creating tmp file for Origin " +
                    "Private Key File");
            return null;
        }
    }
}
